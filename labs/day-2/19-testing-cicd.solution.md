# Lab 19 — Testing in CI/CD — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-2/19-testing-cicd/` unless a step says otherwise.

### Step 1 — Read the real pipeline stages

From the repository root, list the jobs and the unit-lane entrypoint:

```bash
grep -nE '^  [a-z].*:|^    name:|scripts/verify|localstack:' .github/workflows/ci.yml
grep -nE 'fmt -check|UNIT LANE|integration' scripts/verify.sh | head -n 20
```

**Task:** Name the four CI jobs and say which script the unit job runs.

<details><summary>Solution / expected observation</summary>

The workflow defines `lint`, `build`, `verify-unit`, and
`verify-integration`. The unit job runs `bash scripts/verify.sh` (after a
bootstrap self-test). That script enforces `tofu fmt -check`, validates
`modules/` and `examples/`, runs plan/mock `tofu test`, and checks slide↔lab drift.
Integration tests that match `*integration*.tftest.hcl` are deferred to the
LocalStack job.

</details>

---

### Step 2 — Spot the planted defects in the lab workflow

Open the fixture:

```bash
sed -n '1,120p' labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml
```

**Task:** List two defects relative to the real `ci.yml`.

<details><summary>Solution / expected observation</summary>

1. **False-green formatting gate** — `verify-unit` runs `tofu fmt -recursive`
   instead of `bash scripts/verify.sh` (or at least `tofu fmt -check`).
2. **Missing integration lane** — there is no `verify-integration` job with a
   pinned `localstack/localstack:4.9.2` service on port `4566`.

</details>

---

### Step 3 — Prove the false green locally

Copy the fixture, introduce formatting drift, and run the **broken** gate
command the lab workflow uses:

```bash
demo="$(mktemp -d)"
cp labs/day-2/19-testing-cicd/fixture/main.tf "$demo/main.tf"
perl -pi -e 's/^  required_version/ required_version/; s/^  value/ value/' "$demo/main.tf"
tofu fmt "$demo/main.tf"; echo "fmt exit: $?"
```

**Task:** Did the command fail? Is the file still drifted after it ran?

<details><summary>Solution / expected output</summary>

`tofu fmt` prints the filename and exits `0`. It **rewrote** the disposable
copy back to canonical form, so the process succeeded even though the file was
drifted when the command started. That is why a CI step that only runs
`tofu fmt` can look green while the **committed** tree still carries drift
(the runner edits a disposable workspace; it does not push a fix).

Re-introduce drift and enforce instead:

```bash
perl -pi -e 's/^  required_version/ required_version/; s/^  value/ value/' "$demo/main.tf"
tofu fmt -check -diff "$demo/main.tf"; echo "fmt -check exit: $?"
```

Expected shape (exit `3`):

```diff
main.tf
--- old/main.tf
+++ new/main.tf
@@ -1,8 +1,8 @@
 terraform {
- required_version = ">= 1.8"
+  required_version = ">= 1.8"
 }

 output "pipeline_fixture" {
   description = "Canonically formatted marker for the S19 fmt-gate exercise."
- value       = "green"
+  value       = "green"
 }
```

`-check` detects drift and changes nothing — the correct CI gate.

Remove the disposable directory when finished:

```bash
rm -r "$demo"
```

</details>

---

### Step 4 — Repair the unit lane

Edit
`labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml` so `verify-unit`
matches the real job's OpenTofu setup and calls the shared script:

```yaml
  verify-unit:
    name: Verify modules (fmt · validate · tofu test — mock/plan)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: "1.10.3"
      - name: Bootstrap contract · fmt · validate · test (no cloud)
        run: |
          bash scripts/bootstrap-selftest.sh
          bash scripts/verify.sh
```

**Task:** Confirm the planted `tofu fmt -recursive` step is gone.

<details><summary>Solution / expected observation</summary>

The unit job no longer claims formatting by rewriting. It delegates to
`scripts/verify.sh`, which already runs `tofu fmt -check` and the rest of the
unit lane. Grepping the fixture should show `verify.sh` and must not show a
bare `tofu fmt -recursive` gate:

```bash
grep -nE 'verify\.sh|tofu fmt' labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml
```

</details>

---

### Step 5 — Assemble the LocalStack service lane

Still in the fixture workflow, add a `verify-integration` job modelled on the
real `ci.yml`: pinned image `localstack/localstack:4.9.2`, port `4566`, health
check, and a step that runs integration filters with
`AWS_ENDPOINT_URL=http://localhost:4566`.

You may copy the job body from `.github/workflows/ci.yml` into the lab
fixture — that is intentional; the real file is the source of truth.

**Task:** After editing, the fixture must name both `verify-unit` and
`verify-integration`, and must mention `localstack/localstack:4.9.2`.

<details><summary>Solution / expected observation</summary>

A minimal check from the repository root:

```bash
grep -nE 'verify-unit:|verify-integration:|localstack/localstack:4.9.2|scripts/verify.sh' \
  labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml
```

You should see all four patterns. The service block should include
`ports: ["4566:4566"]` and a health command against
`http://localhost:4566/_localstack/health`, matching the real workflow.

Remember: assembling this YAML does **not** start LocalStack. The environment
badge for this lab stays `mock ✓ (paper + fixture · no docker)`.

</details>

## Expected observations

- Real CI separates lint/build, unit (`verify.sh`), and LocalStack integration.
- `tofu fmt` without `-check` exits zero on drift after rewriting — a false green.
- `tofu fmt -check` exits non-zero and leaves the file unchanged.
- Environment badges must not claim LocalStack for a paper-only YAML exercise.

## Cleanup / panic reset

Restore the lab fixture workflow (and the formatted marker, if touched):

```bash
git restore -- \
  labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml \
  labs/day-2/19-testing-cicd/fixture/main.tf
git status --short -- labs/day-2/19-testing-cicd
```

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-2/19-testing-cicd` prints nothing. This lab
creates no OpenTofu state, provider downloads, or background services when you
use the `mktemp` demo directory from Step 3.

</details>

## Stretch (optional) — run the pipeline for real

**+~15 min, outside the 30-minute estimate. Needs a GitHub account and
network access.** Nothing later in the workshop depends on this stretch.

**Skip path (no GitHub account, or an offline venue):** run the real unit
lane locally once and confirm it stays green without Docker:

```bash
task verify
```

<details><summary>Solution / expected observation</summary>

`task verify` invokes `scripts/verify.sh`. It should pass preflight, formatting,
validate/test for `modules/` and `examples/`, and drift checks. It must not require
LocalStack. Integration coverage remains a separate concern
(`verify-integration` in CI, or `task verify:integration` when you intentionally
start the emulator).

</details>

Everything so far was paper: you assembled and repaired workflow YAML, but no
runner ever executed it. To watch your pipeline run, push it to a fork of this
repository — GitHub Actions supplies the Ubuntu runner and the Docker engine
this lab deliberately avoided on your machine.

### Fork the workshop and enable Actions

Fork via the **Fork** button on
`https://github.com/PlatformRelay/OpenTofu-Workshop`, or with the GitHub CLI
(this clones the fork into a new `OpenTofu-Workshop/` directory):

```bash
gh repo fork PlatformRelay/OpenTofu-Workshop --clone
```

> **This is the expected edge case, not a mistake:** new forks start with the
> inherited workflows **disabled**. On your fork, open the **Actions** tab and
> press **"I understand my workflows, go ahead and enable them"**. Until you
> do, pushes to the fork trigger nothing at all.

### Put the fixture where Actions can see it

GitHub only executes workflows that sit in the repository-root
`.github/workflows/`. The lab fixture lives under `labs/day-2/…` precisely so
it can never run by accident. **In your fork clone**, copy the fixture you
repaired in Steps 4–5 to the root, on a branch:

```bash
git switch -c lab19-fork-run
cp labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml .github/workflows/pipeline.yml
git add .github/workflows/pipeline.yml
git status --short
```

<details><summary>Solution / expected output</summary>

```text
A  .github/workflows/pipeline.yml
```

One staged file; the fixture under `labs/` stays untouched — the workflow now
exists in both places on this branch, and only the root copy can run.

</details>

### Predict the fork's verdict before pushing

Root workflows are production territory: this repository's `supply-chain` CI
job requires SHA-pinned actions and explicit least-privilege permissions, and
your copy carries the fixture's teaching-grade `@vN` tags. Ask the same gate
locally what the fork's job will say:

```bash
node scripts/supply-chain-policy.mjs; echo "exit: $?"
```

<details><summary>Solution / captured output</summary>

Captured against the tracked starter fixture (Node 26; your repaired copy adds
jobs, so line numbers and finding counts shift — the verdict class does not):

```text
.github/workflows/pipeline.yml:30: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:31: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:32: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:43: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:44: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:45: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:60: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml:61: third-party action must use an immutable 40-character commit SHA
.github/workflows/pipeline.yml: workflow must declare explicit read-only top-level permissions
exit: 1
```

Leave it red and do **not** pin the fixture: the `@vN` tags are lab material,
and the copy exists only on this throwaway branch of your fork. The point is
that you can now predict the fork's `supply-chain` verdict before any runner
spins up — while your own pipeline's jobs run green beside it.

</details>

### Push and open a pull request in your fork

Both workflows trigger on `pull_request` targeting `main`, so a pushed branch
alone runs nothing — the PR is what fires them:

```bash
git commit -m "lab19 stretch: run the assembled pipeline on my fork"
git push -u origin lab19-fork-run
```

> **Base-repository trap:** for fork branches GitHub preselects
> `PlatformRelay/OpenTofu-Workshop` as the PR base. Switch the **base
> repository** dropdown to `YOUR-USER/OpenTofu-Workshop` (base `main`) so the
> PR — and the pipeline — stays inside your fork. With the CLI, name the repo
> explicitly:

```bash
gh pr create --repo YOUR-USER/OpenTofu-Workshop --base main --head lab19-fork-run \
  --title "Lab 19 stretch: fork-and-run" --body "Run the assembled fixture pipeline."
```

Watch the run on the PR's **Checks** tab, under your fork's **Actions** tab,
or with `gh pr checks --watch --repo YOUR-USER/OpenTofu-Workshop`.

<details><summary>Solution / expected observation (GitHub-side — described, not transcribed)</summary>

Two workflows report on the same commit:

- **Workshop CI (lab fixture)** — your `pipeline.yml`: `lint`, `build`,
  `verify-unit`, and (after Step 5) `verify-integration`. The integration job
  pulls `localstack/localstack:4.9.2` and actually boots it on the runner's
  Docker engine — the pyramid tip executes for real for the first time in
  this lab. Expect a few minutes end to end; the image pull dominates.
- **CI** — the repository's real workflow: its `supply-chain` job fails on
  your copied fixture, exactly as the local prediction said. That red is the
  gate doing its job on an unpinned root workflow — leave it red.

If you push the fixture **without** the Step 4 repair, `verify-unit` still
reports green: the Step 3 false green, now live in a real Actions run —
`tofu fmt` without `-check` cannot fail on drift.

These observations happen on **your fork**, so this lab describes them
instead of pasting a transcript — a captured log from anywhere else would be
fabricated evidence, which is exactly what the false-green exercise taught
you to reject.

</details>

### Clean up the fork

GitHub-side: close the PR and delete the `lab19-fork-run` branch — or delete
the entire fork (**Settings → General → Delete this repository**). In your
fork clone:

```bash
git switch main
git branch -D lab19-fork-run
git status --short
```

If you ran the copy step inside this workshop checkout instead of a fork
clone, remove the stray root copy as well:

```bash
rm -f .github/workflows/pipeline.yml
git status --short -- .github/workflows
```

<details><summary>Solution / expected cleanup</summary>

Both `git status --short` commands print nothing: the branch is gone, the
repository-root `.github/workflows/` holds only the tracked real workflows,
and the lab fixture under `labs/day-2/19-testing-cicd/` is still pristine.

</details>

---

## Expected state / output

- Real CI separates lint/build, unit (`verify.sh`), and LocalStack integration.
- `tofu fmt` without `-check` exits zero on drift after rewriting — a false green.
- `tofu fmt -check` exits non-zero and leaves the file unchanged.
- Environment badges must not claim LocalStack for a paper-only YAML exercise.

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

OpenTofu reconciles declared configuration against stored state on every plan and
apply, so the commands above succeed only when the tracked HCL, provider plugins,
and backend settings match what the lab authored. Each step therefore wires inputs
(outputs, variables, modules, or data sources) before the resources that consume
them, because the graph must be acyclic at evaluation time.

When a step reads remote or emulated cloud APIs (LocalStack or mock providers), the
provider block binds credentials and endpoints first; resources then call those APIs
and persist returned attributes into state. That is why init/plan/apply ordering
matters and why re-running apply without changes reports zero additions.

## Troubleshooting and recovery

If a step fails mid-lab, return to a clean tree before retrying:

Restore the lab fixture workflow (and the formatted marker, if touched):

```bash
git restore -- \
  labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml \
  labs/day-2/19-testing-cicd/fixture/main.tf
git status --short -- labs/day-2/19-testing-cicd
```

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-2/19-testing-cicd` prints nothing. This lab
creates no OpenTofu state, provider downloads, or background services when you
use the `mktemp` demo directory from Step 3.

</details>

Re-enter `labs/day-2/19-testing-cicd/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

Optional, **+~15 min outside the 30-minute estimate**; needs a GitHub account
and network. **Skip path** (offline venue or no account) — run the real unit
lane locally instead:

```bash
task verify
```

Fork-and-run path, executed **in a clone of your fork**
(`gh repo fork PlatformRelay/OpenTofu-Workshop --clone`, then enable workflows
on the fork's **Actions** tab — forks start with them disabled):

```bash
git switch -c lab19-fork-run
cp labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml .github/workflows/pipeline.yml
git add .github/workflows/pipeline.yml
node scripts/supply-chain-policy.mjs
git commit -m "lab19 stretch: run the assembled pipeline on my fork"
git push -u origin lab19-fork-run
gh pr create --repo YOUR-USER/OpenTofu-Workshop --base main --head lab19-fork-run \
  --title "Lab 19 stretch: fork-and-run" --body "Run the assembled fixture pipeline."
```

Cleanup: close the PR, delete the branch (or the whole fork), and remove any
stray root copy made inside the workshop checkout
(`rm -f .github/workflows/pipeline.yml`).

### Expected state / output

- **Local, before the push** — `git status --short` shows exactly
  `A  .github/workflows/pipeline.yml`, and `node scripts/supply-chain-policy.mjs`
  exits `1` naming every `@vN` action line plus the missing top-level
  `permissions` block (captured output in the stretch spoiler above): the
  fork's `supply-chain` verdict, predicted before any runner spins up.
- **On the fork's PR (described, not transcribed — the run happens on your
  fork):** the **Workshop CI (lab fixture)** workflow executes `lint`,
  `build`, `verify-unit`, and (after Step 5) `verify-integration`, which pulls
  and boots `localstack/localstack:4.9.2` on the runner's Docker engine — the
  pipeline actually runs. The repository's real **CI** workflow reds only its
  `supply-chain` job, matching the local prediction. Pushing the fixture
  without the Step 4 repair still shows `verify-unit` green — the Step 3
  false green, live.
- **Skip path:** `task verify` passes the unit lane locally with LocalStack
  idle, same as the pre-stretch behaviour.

### Explanation

The stretch runs the pipeline for real because GitHub Actions only executes
workflows from the repository-root `.github/workflows/`, so copying the
fixture there — on a fork — is what turns paper YAML into a live run, while
the `labs/` placement keeps it inert in the workshop repo. Forks disable
inherited workflows by default, so enabling them on the Actions tab is a
required, documented step, not an error. The predicted `supply-chain` red
follows from a policy boundary: root workflows are held to the production bar
(SHA-pinned actions, explicit least-privilege permissions) because they
execute with repository credentials, whereas the lab fixture keeps
teaching-grade `@vN` tags on purpose — so the same file is acceptable as lab
material and unacceptable as production CI, and the gate proves it can tell
the difference. No secrets are needed because every job only checks out,
builds, and tests, which is also why the run is safe on any learner account.
