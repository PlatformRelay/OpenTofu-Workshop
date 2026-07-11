# Example — `naming-labels-demo`

A small root module that wires the [`naming`](../../modules/naming) and
[`labels`](../../modules/labels) modules into real AWS resources — an
`aws_s3_bucket` and an `aws_dynamodb_table` — running against **LocalStack** so
there is no real cloud cost and no real credentials.

It also demonstrates **OpenTofu native state encryption** (PBKDF2 + AES-GCM),
the S05 ↔ S08 tie-in.

## What it shows

- `module.naming` produces `s3-crmapp-d-web-<hex>` and
  `ddb-crmapp-d-sessions-<hex>`.
- `module.labels` produces one shared tag map applied to both resources.
- The `terraform { encryption { ... } }` block encrypts state *and* plan at rest.

## Prerequisites

- OpenTofu **1.8+** (for `mock_provider` in tests).
- For a real `apply`: [LocalStack](https://localstack.cloud) on `:4566`
  (`docker run --rm -p 4566:4566 localstack/localstack`).

## Run it

```sh
# Passphrase for state encryption — MUST be >= 16 chars. Never commit it.
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'

tofu init
tofu plan          # plans against LocalStack endpoints
tofu apply         # requires LocalStack running on :4566
```

Set `use_localstack = false` to target real AWS instead (you then supply real
credentials the usual way and the custom endpoints are dropped).

## State encryption

`providers.tf` derives an AES-GCM key from `var.state_passphrase` via PBKDF2 and
encrypts both `state` and `plan`. To make OpenTofu **refuse** unencrypted state,
uncomment `enforced = true` in the `state {}` block once every collaborator has
the passphrase. Supply the passphrase out-of-band:

```sh
export TF_VAR_state_passphrase='...'      # or the TF_ENCRYPTION env form
```

## Tests

`tests/integration.tftest.hcl` has two runs:

| Run | Command | Needs LocalStack? | Asserts |
|-----|---------|:-----------------:|---------|
| `unit_plan_with_mock` | `plan` (aliased `mock_provider`) | no | shared label map; required keys present |
| `localstack_apply` | `apply` | **yes** | concrete names match the naming pattern; tags applied |

```sh
# No cloud needed — the mocked plan run passes anywhere:
tofu test         # unit_plan_with_mock passes;
                  # localstack_apply passes only when LocalStack is up (CI),
                  # otherwise fails with "connection refused" to :4566 — expected.
```

> The `mock_provider "aws"` is **aliased** and opted into only by the plan run,
> so it does not shadow the real provider used by the apply run. Without the
> alias, a bare `mock_provider` would mock the apply test too and report a false
> green.
