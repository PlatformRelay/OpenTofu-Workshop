# Supply-chain policy

The repository fails CI when a workflow uses a mutable action reference, a pinned
action lacks a version comment, maintained executable setup code introduces an
ungoverned remote download or execution path, a job requests write permission
outside the allowlist, or a dependency carries an unexcepted high/critical
advisory.

Run the same gates locally:

```sh
pnpm install --frozen-lockfile
node --test scripts/supply-chain-policy.test.mjs scripts/pnpm-overrides.test.mjs
node scripts/supply-chain-policy.mjs

pnpm test:dep-audit
pnpm audit --json > /tmp/pnpm-audit.json; pnpm dep-audit /tmp/pnpm-audit.json
```

Capture the audit to a file before gating it. `pnpm audit` exits non-zero
whenever it finds *any* advisory — including the moderate and low ones the gate
deliberately ignores — so under `set -o pipefail` (which is how GitHub Actions
runs every `run:` block) piping the two together fails on the audit's exit code
regardless of the gate's verdict.

## GitHub Actions policy

Every external action in `.github/workflows/` uses a 40-character commit SHA and
a nearby version comment, for example:

```yaml
- uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4
```

Container actions, if introduced, must use an image digest. Local actions under
`./` are allowed. Renovate's GitHub Actions manager has `pinDigests: true`, so
updates remain reviewable proposals and preserve immutable references.

Every workflow declares read-only permissions at the workflow level. Jobs that
publish a GitHub Release or deploy GitHub Pages opt into only the write or OIDC
permissions they need:

| Workflow | Job | Allowed write scopes |
| --- | --- | --- |
| `pages.yml` | `deploy` | `pages`, `id-token` |
| `release.yml` | `publish` | `contents` |

## Remote downloads

Maintained shell, Python, and Node setup/automation under `setup/`, `scripts/`,
and `.github/` may not download a remote input—or pipe one into a shell—without a
named, documented, unexpired entry in `supply-chain/exceptions.json`. The shell
scanner treats direct `curl`/`wget`, command substitution (`x=$(curl …)`),
`eval "$(curl …)"`, and `source <(curl …)` as remote-input callsites.

Each exception binds an exact HTTPS `source` to one of two auditable kinds:

- `accepted-risk` requires an exact, whitespace-normalized literal `command`
  with no dynamic source. It states plainly that the bytes are not
  checksum-pinned and gives the reason and expiry for that temporary risk
  acceptance;
- `sha256` permits only one deliberately narrow flow: `curl -fsSL <source> -o
  <output>`, then `printf ... | sha256sum -c -`, then `bash <output>`. The source,
  simple output filename, exact digest, verified file, and executed file must
  all match the inventory.

Expired exceptions fail the gate. Bootstrap install hints that only `echo`
commands to the operator are not treated as executable remote-input callsites.

Learner lab workflows under `labs/**/.github/workflows/` are teaching examples
with mutable action tags; they are outside this gate until promoted to
repository CI.

## Dependency advisories

`scripts/npm-audit-gate.mjs` is a **blocking** CI job (US-F-DEP-AUDIT). It reads
`pnpm audit --json` from a file path or stdin and fails on any **high or
critical** advisory that is not covered by a valid, unexpired exception. Only
high and critical block; moderate and low are reported and merge freely.

The gate **fails closed**. A missing file, empty output, non-JSON output, a
payload with no `metadata.vulnerabilities` block, non-numeric severity counts, a
non-object `advisories` map, an advisory with no `github_advisory_id`, an unknown
severity, or an advisory list shorter than the report's own counts all exit
non-zero. "We could not read the advisories" is never allowed to read as "there
are no advisories" — so a broken audit command blocks the merge instead of
waving it through.

The decision logic is a pure function (`evaluateAudit()`) with no I/O, clock, or
network, so the whole policy is tested offline against the fixtures in
`scripts/fixtures/npm-audit/` — trimmed snapshots of real `pnpm audit --json`
output.

### Fixing a high or critical finding

**Patch it if you can — a published patch always replaces an exception.** Add a
bounded override to `pnpm-workspace.yaml`, pinned to the *first patched version
on that major line* rather than across a major boundary, and assert it in
`scripts/pnpm-overrides.test.mjs`. If pnpm's `minimumReleaseAge` gate rejects a
freshly published pin, move the `minimumReleaseAgeExclude` entry to the same
version — the overrides test asserts the two agree so they cannot drift apart.
Then refresh the lockfile (`pnpm install --lockfile-only`) and confirm
`pnpm install --frozen-lockfile` still succeeds, since CI uses the frozen form.

### Adding an exception

An exception is only legitimate **while no patched release exists**. Add an
entry to `npmAdvisories` in `supply-chain/exceptions.json`:

```json
{
  "id": "GHSA-w3rx-r6r6-pgpr",
  "module": "image-size",
  "reason": "why no patch can be applied, and why the code path is not reachable here",
  "owner": "@PlatformRelay",
  "expires": "2026-11-16"
}
```

- `id` must be the **GHSA identifier**, not the numeric npm advisory id — the
  numeric ids are registry-internal and unstable;
- `module` must name the affected package and is **checked against the
  advisory's `module_name`**. A waiver applies to one package only; an entry
  with the right GHSA but the wrong module shields nothing and fails the gate;
- `reason`, `owner`, and an ISO `YYYY-MM-DD` `expires` are all required. A
  missing field, a malformed or impossible date, a non-GHSA id, a duplicate
  entry, or an `npmAdvisories` value that is not an array fails the gate;
- an **expired** exception both fails the gate *and* stops shielding its
  advisory, so letting one lapse can never quietly widen what is allowed
  through;
- `expires` may not sit more than **180 days** out. An exception is a temporary
  risk acceptance, not a permanent waiver, so a far-future date is rejected
  rather than quietly accepted. The shipped entries use ~90 days.

The registry file itself must exist and must contain an `npmAdvisories` key —
both a missing file and a missing key fail the gate. Declare "no exceptions"
with an explicit empty array, never by deleting the file or the key, so that a
moved or renamed registry can never be mistaken for a governed empty one.

When an exception stops matching any current advisory — the usual sign that a
patch has landed — the gate prints a warning naming it, but does not fail.
Blocking there would red the gate for a non-security reason (a transitive
dependency simply disappearing); the `expires` horizon is what caps a forgotten
waiver. Delete the entry when you see the warning.

This registry shares a file with the remote-input exceptions above but not their
schema — `npmAdvisories` and `remoteInputs` have separate validators and neither
reads the other's array.

### Current exceptions

Two `image-size` advisories (GHSA-w3rx-r6r6-pgpr, GHSA-5p2g-fcmc-qvqq) are
excepted because they are **unpatchable**, not merely unpatched: the advisories'
`>=2.0.3` floor is not published on the registry (latest is 2.0.2, and the
resolved 1.2.1 is the last 1.x release), and `pptxgenjs` still requires
`image-size@^1.2.1`, so no override reaches a fixed version without breaking that
major range. The only paths are `@slidev/cli > pptxgenjs > image-size` and
`@slidev/cli > @slidev/client > pptxgenjs > image-size`, and **nothing in this
repository invokes `slidev export --format pptx`** — no package.json script, no
Taskfile target, no workflow. Delete both entries the moment a patched
`image-size` publishes.

## Residual scope

This gate covers the npm dependency tree only. It does not block moderate or low
advisories, and it does not replace Renovate, which continues to propose upgrades
as reviewable PRs. `scripts/verify.sh` is the OpenTofu module gate (fmt,
validate, `tofu test`) and does not run the Node supply-chain suites; these gates
live in CI and in the local commands above. SBOM retention for release artifacts
remains separate.
