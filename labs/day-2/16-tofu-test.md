# Lab 16 — Native testing with `tofu test`

| | |
| --- | --- |
| **Section** | S16 — Native testing — `tofu test` |
| **Environment** | mock ✓ · built-in apply ✓ · localstack not required · real-aws optional ✗ |
| **Estimated time** | 35 minutes |

## Objective

Run native plan and apply tests, read an assertion failure, restore the contract,
and prove an invalid input is rejected with `expect_failures`.

## Prerequisites

- OpenTofu 1.8 or newer (`tofu version`)
- A shell at the workshop repository root
- No Docker, cloud account, credentials, or network provider download

## Files used

- `labs/day-2/16-tofu-test/main.tf` — provider-free configuration under test
- `labs/day-2/16-tofu-test/main.tftest.hcl` — native test suite

Do not edit either tracked file for the break exercise. A CLI variable creates a
temporary mismatch, so fixing the test is one safe rerun.

## Step 1 — Inspect the configuration under test

```bash
cd labs/day-2/16-tofu-test
sed -n '1,240p' main.tf
```

The built-in `terraform_data` resource makes an apply run exercise a real
create/read/destroy lifecycle without a provider API.

<details><summary>Solution / expected file</summary>

<!-- source: labs/day-2/16-tofu-test/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
}

variable "project" {
  description = "Project slug under test."
  type        = string
  default     = "crmapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{3,9}$", var.project))
    error_message = "project must be 4-10 lowercase letters or digits, starting with a letter."
  }
}

variable "expected_project" {
  description = "Expected project used by the intentional assertion exercise."
  type        = string
  default     = "crmapp"
}

resource "terraform_data" "manifest" {
  input = {
    project = var.project
  }
}

output "project" {
  value = terraform_data.manifest.output.project
}
```

</details>

## Step 2 — Read the native test suite

```bash
sed -n '1,260p' main.tftest.hcl
```

Before opening the spoiler, identify the shared fixture, the plan boundary, the
apply boundary, and the checkable object expected to fail.

<details><summary>Solution / expected file</summary>

<!-- source: labs/day-2/16-tofu-test/main.tftest.hcl -->
```hcl
variables {
  project = "crmapp"
}

run "project_plan_contract" {
  command = plan

  assert {
    condition     = terraform_data.manifest.input.project == var.expected_project
    error_message = "expected ${var.expected_project}, planned ${terraform_data.manifest.input.project}."
  }
}

run "project_apply_contract" {
  command = apply

  assert {
    condition     = output.project == "crmapp"
    error_message = "applied project should be crmapp, got ${output.project}."
  }
}

run "invalid_project_is_rejected" {
  command = plan

  variables {
    project = "BAD!"
  }

  expect_failures = [
    var.project,
  ]
}
```

The root `variables` block is shared. The second run performs an apply. The last
run passes only when `var.project` produces its validation diagnostic.

</details>

## Step 3 — Initialize, validate, and run green

```bash
tofu init -no-color
tofu validate -no-color
tofu test -no-color
```

<details><summary>Solution / expected output</summary>

```console

Initializing the backend...

Initializing provider plugins...
- terraform.io/builtin/terraform is built in to OpenTofu

OpenTofu has been successfully initialized!

You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure. All OpenTofu commands
should now work.

If you ever set or change modules or backend configuration for OpenTofu,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
Success! The configuration is valid.
main.tftest.hcl... pass
  run "project_plan_contract"... pass
  run "project_apply_contract"... pass
  run "invalid_project_is_rejected"... pass

Success! 3 passed, 0 failed.
```

</details>

## Step 4 — Break the assertion and read it

Override only the expected value; the tracked files stay unchanged:

```bash
tofu test -no-color -var='expected_project=orders'
```

The command must exit non-zero. Which value is expected, and which value did the
plan actually contain?

<details><summary>Solution / expected failure</summary>

```console
main.tftest.hcl... fail
  run "project_plan_contract"... fail
  run "project_apply_contract"... pass
  run "invalid_project_is_rejected"... pass

Error: Test assertion failed

  on main.tftest.hcl line 9, in run "project_plan_contract":
   9:     condition     = terraform_data.manifest.input.project == var.expected_project
    ├────────────────
    │ terraform_data.manifest.input.project is "crmapp"
    │ var.expected_project is "orders"
    ├────────────────
    │ Diff:
    │     "crmapp" -> "orders"

expected orders, planned crmapp.

Failure! 2 passed, 1 failed.
```

`orders` is the deliberately overridden expectation. `crmapp` is the planned
value observed in the resource input.

</details>

## Step 5 — Fix and prove the suite is green

Remove the temporary CLI override by rerunning the normal command:

```bash
tofu test -no-color
```

<details><summary>Solution / expected output</summary>

The suite again ends with:

```console
Success! 3 passed, 0 failed.
```

</details>

## Expected observations

- `command = plan` proves a planned value without creating the resource.
- `command = apply` exercises creation and OpenTofu's automatic test cleanup.
- The invalid input run passes because `expect_failures` names `var.project`.
- An assertion failure prints its source location, observed values, and message.
- The test directory contains no persistent state after the suite finishes.

## Stretch — Inspect apply output and filter one run

Run the apply scenario verbosely, then execute only the negative test:

```bash
tofu test -no-color -verbose -filter=main.tftest.hcl
tofu test -no-color -filter=main.tftest.hcl
```

<details><summary>Solution / expected observations</summary>

The verbose transcript from OpenTofu 1.12.3 is below. Your generated `id` will
differ; all other lines should have the same shape.

```console
main.tftest.hcl... pass
  run "project_plan_contract"... pass

OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

OpenTofu will perform the following actions:

  # terraform_data.manifest will be created
  + resource "terraform_data" "manifest" {
      + id     = (known after apply)
      + input  = {
          + project = "crmapp"
        }
      + output = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + project = (known after apply)
  run "project_apply_contract"... pass
# terraform_data.manifest:
resource "terraform_data" "manifest" {
    id     = "33b2001d-92a6-7643-c024-19c00c0192d8"
    input  = {
        project = "crmapp"
    }
    output = {
        project = "crmapp"
    }
}


Outputs:

project = "crmapp"
  run "invalid_project_is_rejected"... pass

Planning failed. OpenTofu encountered an error while generating this plan.


Success! 3 passed, 0 failed.
```

`Planning failed` is the diagnostic expected by the negative test, so the suite
still passes. The filtered non-verbose command prints:

```console
main.tftest.hcl... pass
  run "project_plan_contract"... pass
  run "project_apply_contract"... pass
  run "invalid_project_is_rejected"... pass

Success! 3 passed, 0 failed.
```

The `-filter` flag selects test files, not individual `run` blocks; this file
contains all three.

</details>

## Cleanup / panic reset

OpenTofu destroys resources created by an apply test automatically. Confirm that
no state or generated provider directory remains, then return to the root:

```bash
test ! -e terraform.tfstate
test ! -e terraform.tfstate.backup
cd ../../..
```

<details><summary>Panic reset</summary>

If a test was interrupted, return to the lab directory and rerun `tofu test`.
For this built-in, provider-free fixture there is no external resource to clean
up. The tracked `main.tf` and `main.tftest.hcl` are the reset baseline.

Both `test ! -e` commands are silent on success.

</details>
