# Lab 16 — Native testing with `tofu test`

| | |
| --- | --- |
| **Section** | S16 — Native testing — `tofu test` |
| **Environment** | localstack ✓ · plan ✓ · real-aws (optional) ✗ |
| **Estimated time** | 35 minutes |

## Objective

Run the existing naming module's plan tests, including its expected-failure
cases, then use a native apply test to create and verify a module-named S3 bucket
against the repository's pinned LocalStack 4.9.2.

## Prerequisites

- OpenTofu 1.8 or newer (`tofu version`)
- Docker with Compose v2 (`docker compose version`)
- Ports `4566` free
- A shell at the workshop repository root
- No cloud account or real AWS credentials

## Files used

- `modules/naming/` — the real module and seven plan-only native tests
- `labs/day-2/16-tofu-test/main.tf` — S3 fixture using that module
- `labs/day-2/16-tofu-test/tests/integration.tftest.hcl` — LocalStack apply test
- `docker-compose.yml` — LocalStack pinned to `localstack/localstack:4.9.2`

## Step 1 — Run the naming module's plan suite

From the repository root:

```bash
tofu -chdir=modules/naming init -no-color
tofu -chdir=modules/naming test -no-color
```

Read the run names. Which three prove invalid input is rejected?

<details><summary>Solution / expected output</summary>

This is the transcript from OpenTofu 1.12.3 with the provider already cached:

```console

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/random from the dependency lock file
- Using previously-installed hashicorp/random v3.9.0

OpenTofu has been successfully initialized!

You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure. All OpenTofu commands
should now work.

If you ever set or change modules or backend configuration for OpenTofu,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
tests/naming.tftest.hcl... pass
  run "full_name_composition"... pass
  run "optional_components_omitted"... pass
  run "random_suffix_path_plans"... pass
  run "profile_swap_override"... pass
  run "unknown_resource_type_fails"... pass
  run "bad_project_length_fails"... pass
  run "unknown_environment_fails"... pass

Success! 7 passed, 0 failed.
```

The last three runs use `expect_failures`. They pass because the named
variable or output check rejects the invalid case. A first run may say
`Installing` instead of `Using previously-installed`.

</details>
## Step 2 — Inspect the LocalStack fixture

The fixture consumes the same module and points only S3 at localhost:

```bash
sed -n '1,240p' labs/day-2/16-tofu-test/main.tf
sed -n '1,160p' labs/day-2/16-tofu-test/tests/integration.tftest.hcl
```

<details><summary>Solution / exact tracked files</summary>

<!-- source: labs/day-2/16-tofu-test/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

variable "project" {
  description = "Project slug passed to the naming module."
  type        = string
  default     = "crmapp"
}

variable "expected_project" {
  description = "Expected project used by the intentional assertion exercise."
  type        = string
  default     = "crmapp"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}

module "name" {
  source = "../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = "dev"
  description   = "web"
}

resource "aws_s3_bucket" "web" {
  bucket = module.name.name
}

output "bucket_name" {
  value = aws_s3_bucket.web.bucket
}
```

<!-- source: labs/day-2/16-tofu-test/tests/integration.tftest.hcl -->
```hcl
run "localstack_apply" {
  command = apply

  assert {
    condition     = can(regex("^s3-${var.expected_project}-d-web-[a-f0-9]{4}$", output.bucket_name))
    error_message = "expected project ${var.expected_project} in bucket name, got ${output.bucket_name}."
  }
}
```

The test file contains one run. `command = apply` creates the bucket, evaluates
the assertion, and then destroys the test resources automatically.

</details>

## Step 3 — Start pinned LocalStack and run the apply test

```bash
task lab:up
cd labs/day-2/16-tofu-test
tofu init -no-color
tofu validate -no-color
tofu test -no-color -filter=tests/integration.tftest.hcl
```

<details><summary>Solution / expected output</summary>

The startup must report the pinned service as healthy:

```console
Waiting for LocalStack to become healthy at http://localhost:4566/_localstack/health ...
LocalStack is healthy -> http://localhost:4566
```

A fresh init selects AWS 5.100.0 and random 3.9.0; after the init guidance,
validation and the apply test print:

```console
Success! The configuration is valid.
tests/integration.tftest.hcl... pass
  run "localstack_apply"... pass

Success! 1 passed, 0 failed.
```

The random four-character suffix changes on every apply. A cached init says
`Using previously-installed`; neither variation changes the test result.

</details>

## Step 4 — Break the apply assertion and read it

Keep the actual project `crmapp`, but temporarily demand `orders`:

```bash
tofu test -no-color -filter=tests/integration.tftest.hcl \
  -var='expected_project=orders'
```

The command must exit non-zero. Which value is the expectation, and which value
was created in LocalStack?

<details><summary>Solution / captured failure</summary>

This is the verbatim OpenTofu 1.12.3 transcript from the authoring run. Your
random suffix will differ.

```console
tests/integration.tftest.hcl... fail
  run "localstack_apply"... fail

Error: Test assertion failed

  on tests/integration.tftest.hcl line 5, in run "localstack_apply":
   5:     condition     = can(regex("^s3-${var.expected_project}-d-web-[a-f0-9]{4}$", output.bucket_name))
    ├────────────────
    │ output.bucket_name is "s3-crmapp-d-web-3641"
    │ var.expected_project is "orders"

expected project orders in bucket name, got s3-crmapp-d-web-3641.

Failure! 0 passed, 1 failed.
```

`orders` is the overridden expectation. The observed bucket contains
`crmapp`. OpenTofu still cleans up the failed test's bucket.

</details>

## Step 5 — Fix, rerun, and verify cleanup

Remove the temporary override by running the normal command:

```bash
tofu test -no-color -filter=tests/integration.tftest.hcl
```

<details><summary>Solution / expected output</summary>

```console
tests/integration.tftest.hcl... pass
  run "localstack_apply"... pass

Success! 1 passed, 0 failed.
```

The file filter selects the whole test file. Every `run` in a selected file is
executed; this file currently contains one apply run.

</details>

## Expected observations

- The naming module's seven plan runs need no infrastructure.
- Its three `expect_failures` cases prove validation and output guards reject
  bad inputs.
- The S16 apply run crosses the LocalStack S3 API and observes a concrete random
  suffix.
- A failed assertion shows expected and observed values, then test cleanup runs.
- `-filter` selects files, never an individual `run` block.

## Stretch — Inspect the applied state

Run the selected file verbosely:

```bash
tofu test -no-color -verbose -filter=tests/integration.tftest.hcl
```

<details><summary>Solution / captured output</summary>

This is the verbatim OpenTofu 1.12.3 transcript. Generated IDs and suffixes will
differ.

```console
tests/integration.tftest.hcl... pass
  run "localstack_apply"... pass
# aws_s3_bucket.web:
resource "aws_s3_bucket" "web" {
    arn                         = "arn:aws:s3:::s3-crmapp-d-web-a2bb"
    bucket                      = "s3-crmapp-d-web-a2bb"
    bucket_domain_name          = "s3-crmapp-d-web-a2bb.s3.amazonaws.com"
    bucket_regional_domain_name = "s3-crmapp-d-web-a2bb.s3.us-east-1.amazonaws.com"
    force_destroy               = false
    hosted_zone_id              = "Z3AQBSTGFYJSTF"
    id                          = "s3-crmapp-d-web-a2bb"
    object_lock_enabled         = false
    region                      = "us-east-1"
    request_payer               = "BucketOwner"
    tags_all                    = {}

    grant {
        id          = "75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a"
        permissions = [
            "FULL_CONTROL",
        ]
        type        = "CanonicalUser"
    }

    server_side_encryption_configuration {
        rule {
            bucket_key_enabled = false

            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }

    versioning {
        enabled    = false
        mfa_delete = false
    }
}


# module.name.random_id.suffix[0]:
resource "random_id" "suffix" {
    b64_std     = "ors="
    b64_url     = "ors"
    byte_length = 2
    dec         = "41659"
    hex         = "a2bb"
    id          = "ors"
}


Outputs:

bucket_name = "s3-crmapp-d-web-a2bb"

Success! 1 passed, 0 failed.
```

Verbose mode exposes the state available to assertions. It does not retain that
state after the test completes.

</details>

## Cleanup / panic reset

Return to the repository root and stop LocalStack:

```bash
rm -rf .terraform .terraform.lock.hcl
cd ../../..
task lab:down
```

<details><summary>Solution / expected output</summary>

Compose reports that the `opentofu-workshop-localstack` container and workshop
network were stopped and removed. Confirm it is gone:

```bash
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)"
```

That confirmation is silent on success. Native test resources were already
destroyed by `tofu test`; LocalStack persistence is disabled, so the container
shutdown removes any remaining local service data. The first cleanup command
removes only this lab directory's downloaded providers and generated lock file.

If a run was interrupted, execute `tofu test` once more while LocalStack is up
so OpenTofu can retry cleanup, then run `task lab:down`.

</details>
