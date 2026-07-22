# Lab 12 — Classify the evidence

| | |
| --- | --- |
| **Section** | S12 — Why test IaC + the testing pyramid |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 20 min |

## Objective

Classify infrastructure checks by the boundary they cross, run a real plan-only
contract test, deliberately break its assertion, and restore the fast green signal.

## Prerequisites

- OpenTofu ≥ 1.8 (`tofu version`).
- A terminal at the repository root. No Docker, credentials, or cloud account.

## Files used

- [`labs/day-2/12-testing-pyramid/main.tf`](./12-testing-pyramid/main.tf)
- [`labs/day-2/12-testing-pyramid/main.tftest.hcl`](./12-testing-pyramid/main.tftest.hcl)

## Step 1 — Classify by boundary

Put each check in **static**, **unit/contract**, **integration**, or **e2e**:

1. `tofu fmt -check`
2. `tofu validate`
3. `tofu test` with `command = plan` and `mock_provider`
4. apply an S3 bucket to LocalStack and read it back
5. deploy a complete stack to a production-like account and probe its endpoint

**Task:** Explain what must be real for each check—not merely which command runs.

<details><summary>Solution / expected classification</summary>

| Check | Layer | Why |
| --- | --- | --- |
| `fmt -check` | static | reads configuration text only |
| `validate` | static *(debatable)* | creates nothing; provider schemas give it a contract flavour |
| mocked plan test | unit/contract | evaluates a controlled plan without a service API |
| LocalStack apply/read | integration | crosses an emulated service API boundary |
| complete environment probe | e2e | exercises the assembled system |

`tofu validate` is the intentional edge case. Calling it static is useful in
this workshop because it is fast and creates nothing; calling schema validation
a lightweight contract check is also defensible if you state that boundary.

</details>

## Step 2 — Inspect the tracked contract

<!-- source: labs/day-2/12-testing-pyramid/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
}

variable "expected_category" {
  description = "Expected contract classification used by the plan-only test."
  type        = string
  default     = "unit-contract"
}

locals {
  actual_category = "unit-contract"
}

output "actual_category" {
  description = "The boundary exercised by this fixture."
  value       = local.actual_category
}
```

<!-- source: labs/day-2/12-testing-pyramid/main.tftest.hcl -->
```hcl
run "classify_plan_contract" {
  command = plan

  assert {
    condition     = output.actual_category == var.expected_category
    error_message = "Expected ${var.expected_category}, classified ${output.actual_category}."
  }
}
```

**Task:** Predict which boundary this test crosses and whether it creates resources.

<details><summary>Solution</summary>

It evaluates an OpenTofu plan and an output contract. It crosses no service API
boundary and creates no resources, so it belongs in the unit/contract layer.

</details>

## Step 3 — Run the green contract

```bash
cd labs/day-2/12-testing-pyramid
tofu init
tofu validate
tofu test
```

**Task:** Confirm the tracked fixture is valid and the contract passes.

<details><summary>Solution / expected output</summary>

```console
Success! The configuration is valid.

main.tftest.hcl... pass
  run "classify_plan_contract"... pass

Success! 1 passed, 0 failed.
```

</details>

## Step 4 — Break, read, fix

Override the expected category without editing the tracked files:

```bash
tofu test -var='expected_category=integration'
```

**Task:** Read the assertion message. Which side is the expected contract, and
which side is the observed classification?

<details><summary>Solution / expected failure</summary>

```console
main.tftest.hcl... fail
  run "classify_plan_contract"... fail

Error: Test assertion failed
Expected integration, classified unit-contract.

Failure! 0 passed, 1 failed.
```

`integration` is the overridden expectation; `unit-contract` is the observed
output. Fix the input by returning to the tracked default:

```bash
tofu test
```

The final line is `Success! 1 passed, 0 failed.`

</details>

## Expected observations

- Plan-only tests provide a fast contract signal without infrastructure.
- A useful assertion names expected and observed values.
- Tool names alone do not define layers; the boundary crossed does.
- This test cannot expose permissions, latency, or a real API response.

## Cleanup / panic reset

This provider-free plan creates no resources, state, or provider metadata. Return to the workshop root:

```bash
cd ../../..
```

The tracked `main.tf` and `main.tftest.hcl` remain unchanged.

## Stretch (optional)

Run the test verbosely and identify the planned output:

```bash
cd labs/day-2/12-testing-pyramid
tofu init
tofu test -verbose
```

<details><summary>Solution / expected observation</summary>

The verbose plan includes:

```console
Changes to Outputs:
  + actual_category = "unit-contract"
```

The run still ends with `Success! 1 passed, 0 failed.` Clean up again with the
commands above.

</details>
