# Lab 00 — Set up & first apply (S00)

| | |
| --- | --- |
| **Section** | S00 — Welcome & setup *(red line: **arrive** → author → test → scale)* |
| **Environment** | `localstack ✓` · `local ✓ (no docker)` |
| **Estimated time** | 20 min |

## Objective

Verify the toolchain, run a first `tofu apply` against the local provider, then
start the pinned LocalStack environment and create an emulated
`aws_s3_bucket`—proof that the full workshop path works without a cloud account.

## Prerequisites

- The repository cloned, with a terminal in its root.
- Docker running for the primary LocalStack path. A Docker-free Kubernetes
  route is documented in [`setup/localstack.md`](../../setup/localstack.md).

## Files used

- [`labs/day-1/00-setup/hello.tf`](./00-setup/hello.tf) — provider requirements,
  a local file, and the optional `random_pet` stretch resource.
- [`labs/day-1/00-setup/bucket.tf`](./00-setup/bucket.tf) — the LocalStack AWS
  provider and an opt-in S3 bucket.

Work in the tracked directory throughout:

```bash
cd labs/day-1/00-setup
```

---

## Step 1 — Verify the toolchain

From the repository root, run:

```bash
task setup
tofu version
```

**Task:** Confirm `tofu` is at least 1.8.

<details><summary>Solution / expected output</summary>

```console
$ tofu version
OpenTofu v1.12.3
on darwin_arm64
```

Your version and platform may be newer or different. If `task` is missing, run
`bash setup/bootstrap.sh`; it performs the same checks.

</details>

---

## Step 2 — First plan and apply (no Docker, no cloud)

The first file is already tracked—read it before running it:

<!-- source: labs/day-1/00-setup/hello.tf -->
```hcl
terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

variable "enable_random_pet" {
  description = "Create the optional stretch resource."
  type        = bool
  default     = false
}

resource "local_file" "hello" {
  content  = "hello, opentofu\n"
  filename = "${path.module}/hello.txt"
}

resource "random_pet" "stretch" {
  count  = var.enable_random_pet ? 1 : 0
  length = 2
}
```

```bash
tofu init
tofu plan
tofu apply -auto-approve
```

**Task:** What did `apply` create, and where is the state?

<details><summary>Solution / expected output</summary>

```console
$ cat hello.txt
hello, opentofu
$ ls hello.txt terraform.tfstate
hello.txt  terraform.tfstate
```

`apply` created `hello.txt` and recorded it in `terraform.tfstate`. The plan is
the difference between the configuration and that state.

</details>

---

## Step 3 — Check Docker, then start LocalStack

Return to the repository root and test Docker **before** any LocalStack-backed
OpenTofu command:

```bash
cd ../../..
docker info >/dev/null && echo "Docker is ready"
task lab:up
```

If `docker info` fails, start Docker and repeat the check. Do not continue to
Step 4 until `task lab:up` reports `LocalStack is healthy`.

**Task:** Confirm S3 is available on port 4566.

<details><summary>Solution / expected output</summary>

```console
$ curl -s http://localhost:4566/_localstack/health | jq -r '.services.s3'
available
```

The workshop pins the last license-free LocalStack community image. If startup
fails, use the [troubleshooting guide](../../setup/localstack.md#troubleshooting).

</details>

---

## Step 4 — Create the first emulated AWS resource

The second tracked file keeps the LocalStack resource disabled until the health
check has passed:

<!-- source: labs/day-1/00-setup/bucket.tf -->
```hcl
variable "enable_localstack" {
  description = "Create the S3 bucket after LocalStack is healthy."
  type        = bool
  default     = false
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "first" {
  count  = var.enable_localstack ? 1 : 0
  bucket = "my-first-tofu-bucket"
}
```

```bash
cd labs/day-1/00-setup
tofu apply -auto-approve -var='enable_localstack=true'
```

**Task:** List buckets through LocalStack to prove the resource exists.

<details><summary>Solution / expected output</summary>

```console
$ curl -s -H 'Host: s3.localhost.localstack.cloud' http://localhost:4566/ | grep -o '<Name>[^<]*</Name>'
<Name>my-first-tofu-bucket</Name>
```

This is a real AWS resource type served by the local emulator—no account,
credentials, or bill.

</details>

## Expected observations

- `init → plan → apply` is the same workflow for local and AWS-shaped resources.
- The local apply succeeds before Docker or LocalStack is needed.
- LocalStack serves the S3 API locally; no request targets a cloud account.
- State is local for now; Lab 05 encrypts it.

## Stretch (optional)

First prove idempotence:

```bash
tofu apply -auto-approve -var='enable_localstack=true'
```

The summary is `Apply complete! Resources: 0 added, 0 changed, 0 destroyed.`

Then enable the tracked stretch resource and inspect the one-addition plan:

```bash
tofu plan -var='enable_localstack=true' -var='enable_random_pet=true'
tofu apply -auto-approve -var='enable_localstack=true' -var='enable_random_pet=true'
```

<details><summary>Solution / expected output</summary>

```console
Plan: 1 to add, 0 to change, 0 to destroy.

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

</details>

## Cleanup / panic reset

Destroy with both optional paths enabled; this is safe whether or not you ran
the stretch:

```bash
tofu destroy -auto-approve -var='enable_localstack=true' -var='enable_random_pet=true'
cd ../../..
task lab:down
```

Expected final lines:

```console
Destroy complete! Resources: 3 destroyed.
```

If you skipped the stretch, OpenTofu reports two destroyed resources instead.
The tracked `.tf` files remain ready for the next learner; generated state,
lock, and provider files are ignored.
