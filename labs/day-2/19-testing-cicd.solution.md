# Lab 19 — Testing in CI/CD — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-2/19-testing-cicd/` unless a step says otherwise.

### Step 1 — Read the real pipeline stages

From the repository root, list the jobs and the unit-lane entrypoint:

```bash
rg -n '^  [a-z].*:|^    name:|scripts/verify|localstack:' .github/workflows/ci.yml
rg -n 'fmt -check|UNIT LANE|integration' scripts/verify.sh | head -n 20
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
rg -n 'verify\.sh|tofu fmt' labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml
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

## Stretch (optional)

Run the real unit lane once and confirm it stays green without Docker:

```bash
task verify
```

<details><summary>Solution / expected observation</summary>

A minimal check from the repository root:

```bash
rg -n 'verify-unit:|verify-integration:|localstack/localstack:4.9.2|scripts/verify.sh' \
  labs/day-2/19-testing-cicd/.github/workflows/pipeline.yml
```

You should see all four patterns. The service block should include
`ports: ["4566:4566"]` and a health command against
`http://localhost:4566/_localstack/health`, matching the real workflow.

Remember: assembling this YAML does **not** start LocalStack. The environment
badge for this lab stays `mock ✓ (paper + fixture · no docker)`.

</details>

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-2/19-testing-cicd` prints nothing. This lab
creates no OpenTofu state, provider downloads, or background services when you
use the `mktemp` demo directory from Step 3.

</details>

<details><summary>Solution / expected observation</summary>

`task verify` invokes `scripts/verify.sh`. It should pass preflight, formatting,
validate/test for `modules/` and `examples/`, and drift checks. It must not require
LocalStack. Integration coverage remains a separate concern
(`verify-integration` in CI, or `task verify:integration` when you intentionally
start the emulator).

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

(optional)

Run the real unit lane once and confirm it stays green without Docker:

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

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
