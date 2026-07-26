# Example — `capstone`

The **settled colony**: a small LocalStack multi-module root that ties Day 1
(naming, labels, PBKDF2 state encryption) and Day 2 (`tofu test`) together.
Day 3 Terramate orchestration is a **stretch** — the base path is plain
OpenTofu and stays green when Terramate is absent.

Consumes the shared workshop modules:

- [`modules/naming`](../../modules/naming)
- [`modules/labels`](../../modules/labels)

## What it provisions

| Resource | Role | Name pattern (dev / project `colony`) |
|----------|------|----------------------------------------|
| `aws_s3_bucket.artifacts` | artifact store | `s3-colony-d-artifacts-<hex>` |
| `aws_dynamodb_table.index` | metadata index | `ddb-colony-d-index-<hex>` |
| `aws_sqs_queue.work` | async work queue | `sqs-colony-d-work-<hex>` |

One shared `module.labels` tag map is applied to every resource. State and plan
are encrypted at rest (PBKDF2 → AES-GCM).

## Prerequisites

- OpenTofu **1.8+** (for `mock_provider` in tests).
- For a real `apply`: LocalStack on `:4566` (`task lab:up`).

Terramate is **not** required for the base path.

## Run it (base path — no Terramate)

```sh
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'

tofu init
tofu plan
tofu apply          # needs LocalStack on :4566
tofu destroy
```

Or via Taskfile:

```sh
task lab:up
task lab:plan  DIR=examples/capstone
task lab:apply DIR=examples/capstone
task lab:down
```

## State encryption

`providers.tf` derives an AES-GCM key from `var.state_passphrase` via PBKDF2 and
encrypts both `state` and `plan`. Passphrase must be ≥ 16 characters. Supply it
out-of-band (`TF_VAR_state_passphrase`); never commit a real secret.

## Tests

| File | Command | Needs LocalStack? | Covered by |
|------|---------|:-----------------:|------------|
| `tests/unit.tftest.hcl` | `plan` + aliased `mock_provider` | no | `task verify` |
| `tests/encryption.tftest.hcl` | `plan` + PBKDF2 contract check | no | `task verify` |
| `tests/integration.tftest.hcl` | `apply` | **yes** | `task verify:integration` |

```sh
# Unit lane (no Docker, no Terramate):
tofu test -filter=tests/unit.tftest.hcl

# Integration (after task lab:up):
tofu test -filter=tests/integration.tftest.hcl
```

## Stretch — Terramate orchestration

See [`stretch/README.md`](./stretch/README.md). Optional; ignored by
`task verify`. The base root above must keep working without Terramate on
`PATH`.
