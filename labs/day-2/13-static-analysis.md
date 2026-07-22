# Lab 13 — Repair the fast-feedback loop

| | |
| --- | --- |
| **Section** | S13 — Static analysis & formatting |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 30 min |

## Objective

Run three progressively richer static checks against one deliberately messy
module, read each planted defect, repair it, and finish with a clean local gate.

## Prerequisites

- OpenTofu ≥1.8 (`tofu version`).
- TFLint ≥0.58 (`tflint --version`).
- A terminal at the repository root. No credentials, Docker, or cloud account.

## Files used

- [`labs/day-2/13-static-analysis/messy/main.tf`](./13-static-analysis/messy/main.tf)
- [`.tflint.hcl`](../../.tflint.hcl) — the repository's real lint policy.
- [`.pre-commit-config.yaml`](../../.pre-commit-config.yaml) — the repository's
  real commit-time wiring.

The tracked fixture starts broken on purpose:

<!-- source: labs/day-2/13-static-analysis/messy/main.tf -->
```hcl
terraform {
 required_version = ">= 1.8"
}

variable "service_names" {
  description = "Services included in the static-analysis exercise."
 type = list(string)
  default = "payments"
}

variable "legacy_name" {
  description = "Deliberately unused so TFLint has a semantic finding."
  type        = string
  default     = "retired"
}

output "service_count" {
  description = "Number of configured services."
 value = length(var.service_names)
}
```

## Step 1 — Let formatting fail safely

Enter the fixture and ask the formatter to check without rewriting:

```bash
cd labs/day-2/13-static-analysis/messy
tofu fmt -check -diff main.tf
```

**Task:** Identify what the command reports and confirm that the file is still
unchanged.

<details><summary>Solution / expected failure</summary>

The command exits `3`, names `main.tf`, and prints a diff like this:

```diff
main.tf
--- old/main.tf
+++ new/main.tf
@@ -1,11 +1,11 @@
 terraform {
- required_version = ">= 1.8"
+  required_version = ">= 1.8"
 }
```

`-check` detects canonical-format drift but does not edit the file. Repair it:

```bash
tofu fmt main.tf
```

Expected output:

```console
main.tf
```

Now `tofu fmt -check main.tf` is silent and exits `0`.

</details>

## Step 2 — Read the native type error

Run the next layer:

```bash
tofu validate
```

**Task:** Read the diagnostic in order: location, expression, expected type,
then observed type. Which side of the contract should change?

<details><summary>Solution / expected failure</summary>

```console
Error: Invalid default value for variable

  on main.tf line 8, in variable "service_names":
   8:   default = "payments"

This default value is not compatible with the variable's type constraint:
list of string required, but have string.
```

The declared `list(string)` is the intended contract. Make the default a list:

```hcl
  default     = ["payments"]
```

Then rerun:

```bash
tofu fmt main.tf
tofu validate
```

Expected output:

```console
Success! The configuration is valid.
```

</details>

## Step 3 — Let TFLint find valid-but-misleading HCL

Use the repository's checked-in rules and make warnings gate this exercise:

```bash
tflint --config=../../../../.tflint.hcl --minimum-failure-severity=warning
```

**Task:** Name the rule, the finding, and why `tofu validate` did not reject it.

<details><summary>Solution / expected failure</summary>

TFLint exits `2` and reports:

```console
1 issue(s) found:

Warning: [Fixable] variable "legacy_name" is declared but not used (terraform_unused_declarations)

  on main.tf line 11:
  11: variable "legacy_name" {
```

The variable is legal HCL, so native validation passes. The repository's
`terraform_unused_declarations` lint rule adds the stronger convention. Remove
the entire `variable "legacy_name" { ... }` block.

</details>

## Step 4 — Prove the repaired loop is green

Run every layer again:

```bash
tofu fmt -check main.tf
tofu validate
tflint --config=../../../../.tflint.hcl --minimum-failure-severity=warning
```

**Task:** Confirm all three commands exit `0`.

<details><summary>Solution / expected output</summary>

The formatting and TFLint commands are silent. Validation prints:

```console
Success! The configuration is valid.
```

The final file is:

```hcl
terraform {
  required_version = ">= 1.8"
}

variable "service_names" {
  description = "Services included in the static-analysis exercise."
  type        = list(string)
  default     = ["payments"]
}

output "service_count" {
  description = "Number of configured services."
  value       = length(var.service_names)
}
```

</details>

## Step 5 — Inspect the automation boundary

From the repository root, inspect the real hooks that reuse these tools:

```bash
cd ../../../..
rg -n 'terraform_fmt|terraform_tflint|PCT_TFPATH' .pre-commit-config.yaml
```

**Task:** Why does the configuration mention `PCT_TFPATH`?

<details><summary>Solution / expected observation</summary>

The remote hooks support both Terraform and OpenTofu. This repository exports
`PCT_TFPATH="$(command -v tofu)"` so the hooks invoke the workshop's OpenTofu
binary. Pre-commit provides earlier feedback; CI remains the shared gate.

</details>

## Expected observations

- `fmt -check` detects text shape without changing the file.
- `validate` catches a native type-contract violation and points to its source.
- TFLint catches valid HCL that violates the repository's semantic rules.
- The tools complement one another; a green result from one does not replace
  the others.

## Cleanup / panic reset

Restore the deliberately broken tracked fixture for the next learner:

```bash
git restore -- labs/day-2/13-static-analysis/messy/main.tf
git status --short
```

<details><summary>Solution / expected cleanup</summary>

`git status --short` prints nothing. This provider-free lab creates no state,
resources, provider downloads, or background services.

</details>

## Stretch (optional)

Repeat the repair in a throwaway copy and request compact lint output:

```bash
tmp_dir="$(mktemp -d)"
repo_root="$PWD"
cp -R labs/day-2/13-static-analysis/messy/. "$tmp_dir/"
tofu fmt "$tmp_dir/main.tf"
perl -pi -e 's/default     = "payments"/default     = ["payments"]/' "$tmp_dir/main.tf"
(cd "$tmp_dir" && tflint --config="$repo_root/.tflint.hcl" --format=compact)
```

<details><summary>Solution / expected observation</summary>

The compact formatter reports the same rule in one line:

```console
main.tf:11:1: Warning - variable "legacy_name" is declared but not used (terraform_unused_declarations)
```

The warning makes this command exit `2`; compact output changes presentation,
not severity.

Remove the temporary copy when finished:

```bash
rm -r "$tmp_dir"
```

</details>
