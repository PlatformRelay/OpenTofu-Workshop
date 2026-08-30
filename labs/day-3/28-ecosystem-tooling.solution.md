# Lab 28 — Run the everyday tooling belt (S28) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

### Step 1 — Read the version pin (tenv survey)

```bash
grep -n "TOFU_VERSION" versions.env
```

---

<details><summary>Solution / expected observation</summary>

```console
$ grep -n "TOFU_VERSION" versions.env
13:TOFU_VERSION=1.10.3
```

`versions.env` is the toolchain pin's single source of truth — Taskfile,
docker compose, CI, and the bootstrap consume it, and `scripts/verify.sh`
fails on consumer skew. **tenv** — the actively maintained successor to
`tfenv`/`tofuenv`, one binary for OpenTofu, Terraform, Terragrunt, Terramate,
and Atmos — is how a laptop mirrors that pin per project:

```bash
tenv tofu install 1.10.3
tenv tofu use 1.10.3
tofu version
```

The workshop keeps tenv **out of `task setup`** on purpose: `tofu ≥ 1.9` — the
workshop floor — runs every lab. tenv earns its place at work, where
different projects pin different engine versions (e.g. via `.opentofu-version`
files).

</details>

---

### Step 2 — Read the module-docs contract (terraform-docs survey)

```bash
cat modules/naming/.terraform-docs.yml
grep -n "BEGIN_TF_DOCS\|END_TF_DOCS" modules/naming/README.md
```

---

<details><summary>Solution / expected observation</summary>

```console
$ grep -n "BEGIN_TF_DOCS\|END_TF_DOCS" modules/naming/README.md
85:<!-- BEGIN_TF_DOCS -->
109:<!-- END_TF_DOCS -->
```

The checked-in config uses `formatter: markdown table`, shows only `inputs`
and `outputs`, and injects into `README.md` between the two markers
(`output.mode: inject`). The tool owns exactly the marker-bounded region;
the hand-written prose above it is never touched. Regeneration is
`terraform-docs -c .terraform-docs.yml .` from the module directory, and the
repository's `terraform_docs` pre-commit hook enforces the same contract at
commit time.

</details>

---

### Steps 3–5 — Preflight, then break → fix both hooks

```bash
pre-commit --version
export PCT_TFPATH="$(command -v tofu)"

perl -pi -e 's/^  type        = string/ type = string/' labs/day-3/28-ecosystem-tooling/main.tf
pre-commit run terraform_fmt --files labs/day-3/28-ecosystem-tooling/main.tf
pre-commit run terraform_fmt --files labs/day-3/28-ecosystem-tooling/main.tf

perl -pi -e 's/\{$/\{  / if $. == 1' labs/day-3/28-ecosystem-tooling/main.tf
pre-commit run trailing-whitespace --files labs/day-3/28-ecosystem-tooling/main.tf
pre-commit run trailing-whitespace --files labs/day-3/28-ecosystem-tooling/main.tf
git status --short -- labs/day-3/28-ecosystem-tooling/
```

---

<details><summary>Solution / expected failures and auto-fixes</summary>

The first hook run fails **and** repairs the file in the same pass:

```console
tofu fmt.................................................................Failed
- hook id: terraform_fmt
- files were modified by this hook
main.tf
```

The hygiene hook behaves the same way:

```console
trim trailing whitespace.................................................Failed
- hook id: trailing-whitespace
- exit code: 1
- files were modified by this hook
Fixing labs/day-3/28-ecosystem-tooling/main.tf
```

Each rerun prints `Passed`, and the final `git status --short` prints nothing:
canonical formatting is deterministic, so the repaired bytes equal the tracked
bytes. `PCT_TFPATH` is what pointed the `terraform_fmt` hook at `tofu` —
remote hooks' `entry`/`language` are not user-overridable, so the env var is
the supported OpenTofu switch.

If `pre-commit` is missing, install it (`pipx install pre-commit` or
`brew install pre-commit`) — or take the facilitator demo-only path from the
participant lab; the appendix never blocks Day 3.

</details>

---

## Expected state / output

- `grep -n "TOFU_VERSION" versions.env` prints line 13: `TOFU_VERSION=1.10.3`.
- The marker grep prints two lines (`BEGIN_TF_DOCS` / `END_TF_DOCS`) bounding
  the machine-owned README region.
- Both dirty runs print `Failed` with `files were modified by this hook`; both
  reruns print `Passed`.
- After the reruns, `git status --short -- labs/day-3/28-ecosystem-tooling/`
  prints nothing — the working tree matches the tracked fixture exactly.
- No state files, containers, or background processes exist at any point.

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

All three tools live **around** the engine, so each maps onto a file the
repository already tracks. The version pin works because `versions.env` is the
only place a toolchain version may live — every consumer reads it, which means
tenv on a laptop and CI in the cloud can agree on the same engine bytes. The
docs contract works because inject mode gives terraform-docs ownership of an
explicitly marker-bounded region: regeneration is idempotent there, while the
surrounding prose stays human-owned, so docs stay next to the code they
describe without a wiki drifting out of date.

The pre-commit beats fail-then-pass because fixing hooks are deliberately
non-blocking in one direction only: a dirty file fails the commit attempt,
but the hook repairs it in the same pass, so the immediate rerun succeeds.
The repaired file is byte-identical to the tracked one because `tofu fmt` is
deterministic — which is also why the S13 messy fixture and this lab's
cleanup can rely on `git status` proving cleanliness. `PCT_TFPATH` matters
because the `pre-commit-terraform` hooks support both Terraform and OpenTofu;
since a remote hook's `entry` is not user-overridable, the env var is the
supported way to keep the whole suite OpenTofu-first.

## Troubleshooting and recovery

If a hook left the fixture in an unexpected state, or you edited more than
the two planted lines, restore the tracked files and re-check:

```bash
git restore -- labs/day-3/28-ecosystem-tooling/
git status --short -- labs/day-3/28-ecosystem-tooling/
```

If the first `pre-commit run` hangs or fails while `Initializing
environment`, the one-time hook-repo fetch needs network access — rerun on a
working connection, or switch to the facilitator demo-only path. A wrong or
unset `PCT_TFPATH` makes the Terraform-ecosystem hooks look for a `terraform`
binary; re-export it and rerun:

```bash
export PCT_TFPATH="$(command -v tofu)"
pre-commit run terraform_fmt --files labs/day-3/28-ecosystem-tooling/main.tf
```

## Stretch solution

### Commands / manifest

Regenerate the naming module docs with the checked-in config, read the diff,
and restore:

```bash
cd modules/naming
terraform-docs -c .terraform-docs.yml .
git diff --stat -- README.md
git restore -- README.md
cd ../..
```

Mirror the engine pin with tenv:

```bash
tenv tofu install 1.10.3
tenv tofu list
```

### Expected state / output

```console
$ terraform-docs -c .terraform-docs.yml .
README.md updated successfully
```

The tool prints `README.md updated successfully`, and `git diff --stat`
reports a real changed `README.md` (roughly a dozen lines each way): only the
marker-bounded region differs — the tool emits escaped underscores, fully
expanded default values, and its own sort order, where the tracked table was
hand-tidied. After `git restore`, the diff is gone and `git status` output is
clean. For tenv, the pinned `1.10.3` appears in the `tenv tofu list` output;
`tenv tofu uninstall 1.10.3` removes it again.

### Explanation

The regeneration diff exists because inject mode replaces the marker-bounded
region with the tool's canonical rendering, and the tracked README was tidied
by hand after an earlier generation — the markers, not luck, are what keep
the damage reviewable and reversible. Restoring is the right move here
because syncing the README to raw tool output is a maintainer decision that
belongs in its own reviewed commit, not a lab side effect. The tenv stretch
proves the pin is portable: the same version string flows from `versions.env`
through `tenv tofu install` to `tofu version`, which is exactly how a team
keeps laptops and CI on the same engine.
