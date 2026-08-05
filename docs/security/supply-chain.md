# Supply-chain policy

The repository fails CI when a workflow uses a mutable action reference, a pinned
action lacks a version comment, maintained executable setup code introduces an
ungoverned remote download or execution path, or a job requests write permission
outside the allowlist.

Run the same gate locally:

```sh
pnpm install --frozen-lockfile
node --test scripts/supply-chain-policy.test.mjs
node scripts/supply-chain-policy.mjs
```

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
named, documented, unexpired entry in `supply-chain/exceptions.json`.

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

## Residual scope

`pnpm audit` runs in CI as a non-blocking job (US-F-SEC-2). Dependency
high/critical gating and SBOM retention for release artifacts remain separate
workstreams.
