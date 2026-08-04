# Lab 18 — Terratest vs LocalStack (+ optional Infracost)

| | |
| --- | --- |
| **Section** | S18 — Integration, e2e & cost |
| **Environment** | localstack ✓ · mock ✓ |
| **Estimated time** | 30 minutes |

## Objective

Run the provided Terratest suite against pinned LocalStack through the
**container lane** (no host Go), prove apply → assert → destroy, then
deliberately break the Go assertion and restore green. Optionally price a
separate cost fixture with Infracost — **stretch only; free API key required**.

## Prerequisites

- Docker with Compose v2 (`docker compose version`)
- Ports `4566` free (or stop another workshop LocalStack first)
- A shell at the workshop repository root
- **No** host Go toolchain required for the core lab
- **No** cloud account; **no** Infracost key for the core lab

## Files used

- [`labs/day-2/18-terratest-cost/main.tf`](./18-terratest-cost/main.tf) — LocalStack S3 root
- [`labs/day-2/18-terratest-cost/bucket_test.go`](./18-terratest-cost/bucket_test.go) — Terratest e2e
- [`labs/day-2/18-terratest-cost/go.mod`](./18-terratest-cost/go.mod) — pinned Terratest module
- [`labs/day-2/18-terratest-cost/cost/main.tf`](./18-terratest-cost/cost/main.tf) — Infracost stretch fixture (never applied by Terratest)
- `docker-compose.yml` — LocalStack `4.9.2` + optional `terratest` profile

## Step 1 — Inspect the OpenTofu root and the Go test

```bash
sed -n '1,80p' labs/day-2/18-terratest-cost/main.tf
sed -n '1,50p' labs/day-2/18-terratest-cost/bucket_test.go
```

Which variable lets the same test hit `localhost` on a host Go lane and the
Compose DNS name `localstack` inside the container?

<details><summary>Solution / exact tracked files</summary>

<!-- source: labs/day-2/18-terratest-cost/main.tf -->
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
  description = "Project slug used in the deterministic bucket name."
  type        = string
  default     = "crmapp"
}

variable "aws_endpoint" {
  description = "S3 API endpoint. Host labs use localhost; the Terratest container uses the Compose DNS name localstack."
  type        = string
  default     = "http://localhost:4566"
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
    s3 = var.aws_endpoint
  }
}

resource "aws_s3_bucket" "web" {
  bucket = "s3-${var.project}-d-web-tt"
}

output "bucket_name" {
  value = aws_s3_bucket.web.bucket
}
```

The Go test reads `AWS_ENDPOINT_URL` (set to `http://localstack:4566` in the
compose service) and passes it as `aws_endpoint`. `TerraformBinary` is `tofu`.
`defer terraform.Destroy` runs even when an assertion fails.

</details>

## Step 2 — Run Terratest via the container lane

From the repository root (no `go` install needed):

```bash
task lab:terratest DIR=labs/day-2/18-terratest-cost
```

<details><summary>Solution / expected output</summary>

Compose brings up LocalStack, builds or reuses the pinned Terratest image, then
runs `go test`. A successful authoring run ended with:

```console
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

bucket_name = "s3-crmapp-d-web-tt"
...
Destroy complete! Resources: 1 destroyed.
--- PASS: TestLocalStackS3Bucket (29.14s)
PASS
ok  	github.com/platformrelay/opentofu-workshop/labs/day-2/18-terratest-cost	29.141s
```

Provider download lines (`Installing hashicorp/aws v5.100.0`) appear on a cold
cache; timing varies. The durable signal is **PASS** after destroy.

If Docker cannot bind-mount the repo (common when the clone lives under
`/tmp` on Docker Desktop), the script fails fast and points at the host-Go
lane: `BOOTSTRAP_WITH_GO=1 bash setup/bootstrap.sh` then
`task lab:up && task lab:terratest:host DIR=labs/day-2/18-terratest-cost`.

</details>

## Step 3 — Break the assertion and read the failure

Temporarily demand the wrong bucket name in the Go test:

```bash
# macOS / BSD sed:
sed -i '' 's/"s3-crmapp-d-web-tt"/"s3-orders-d-web-tt"/' \
  labs/day-2/18-terratest-cost/bucket_test.go
# Linux GNU sed: sed -i 's/"s3-crmapp-d-web-tt"/"s3-orders-d-web-tt"/' …

task lab:terratest DIR=labs/day-2/18-terratest-cost
```

The command must exit non-zero. Which value was expected, and which was created?

<details><summary>Solution / captured failure</summary>

This is the verbatim container-lane transcript from the authoring run. Destroy
still ran after the failed assert:

```console
    bucket_test.go:44:
        	Error Trace:	/workspace/labs/day-2/18-terratest-cost/bucket_test.go:44
        	Error:      	Not equal:
        	            	expected: "s3-orders-d-web-tt"
        	            	actual  : "s3-crmapp-d-web-tt"

        	            	Diff:
        	            	--- Expected
        	            	+++ Actual
        	            	@@ -1 +1 @@
        	            	-s3-orders-d-web-tt
        	            	+s3-crmapp-d-web-tt
        	Test:       	TestLocalStackS3Bucket
...
Destroy complete! Resources: 1 destroyed.
--- FAIL: TestLocalStackS3Bucket (12.92s)
FAIL
```

`s3-orders-d-web-tt` is the poisoned expectation. LocalStack still created
`s3-crmapp-d-web-tt`, and `defer Destroy` removed it.

</details>

## Step 4 — Restore and re-run green

```bash
git checkout -- labs/day-2/18-terratest-cost/bucket_test.go
task lab:terratest DIR=labs/day-2/18-terratest-cost
```

<details><summary>Solution / expected output</summary>

```console
--- PASS: TestLocalStackS3Bucket (…s)
PASS
ok  	github.com/platformrelay/opentofu-workshop/labs/day-2/18-terratest-cost	…s
```

If you are mid-authoring and the file was never committed, restore the Equal
line to `"s3-crmapp-d-web-tt"` by hand instead of `git checkout`.

</details>

## Expected observations

- The container lane runs Go + OpenTofu; the laptop needs Docker, not a Go
  toolchain.
- Terratest applies real (emulated) infrastructure, asserts in Go, then destroys.
- A failed assert still tears down — watch for `Destroy complete!`.
- Native `tofu test` remains the default for HCL-expressible contracts; this
  tip is for claims that escape HCL.

## Stretch — Infracost breakdown (optional · free API key)

> **Optional stretch — requires a free Infracost API key.** Skip this entire
> section and the core lab still succeeds. The no-signup promise holds.

The stretch fixture under `cost/` is **not** applied by Terratest. It exists so
Infracost can price an instance from HCL alone:

```bash
sed -n '1,40p' labs/day-2/18-terratest-cost/cost/main.tf
```

<details><summary>Solution / exact cost fixture</summary>

<!-- source: labs/day-2/18-terratest-cost/cost/main.tf -->
```hcl
# Cost-estimation fixture for the optional Infracost stretch.
# Not applied by the Terratest suite — pricing is inferred from HCL only.
terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "s18-cost-demo"
  }
}
```

</details>

If you already have a key:

```bash
# one-time: https://www.infracost.io → free API key
export INFRACOST_API_KEY=…   # or: infracost auth login
infracost breakdown --path labs/day-2/18-terratest-cost/cost --no-color
```

<details><summary>Solution / demo shape (slides carry a captured table)</summary>

Without a key the CLI refuses to run — that is expected. With a key you should
see a monthly table for `aws_instance.web` (on-demand `t3.micro` + gp3 root
volume) and an overall total. Exact currency figures drift with the pricing
API; compare your output to the **captured demo** on the S18 slides, not to a
fixed dollar amount in this spoiler.

A PR comment would run the same breakdown against the base branch and post the
diff — still optional for this workshop.

</details>

## Cleanup / panic reset

From the repository root (restore the break file first if you left Step 3
poisoned):

```bash
git checkout -- labs/day-2/18-terratest-cost/bucket_test.go
task lab:down
# optional: remove provider / module caches left by Terratest
rm -rf labs/day-2/18-terratest-cost/.terraform \
       labs/day-2/18-terratest-cost/terraform.tfstate*
```

<details><summary>Solution / expected output</summary>

`git checkout` is a no-op when `bucket_test.go` is already clean. Compose stops
and removes `opentofu-workshop-localstack`. Confirm:

```bash
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)"
```

Silent success. Terratest already destroyed the bucket on every green or failed
run that reached `defer Destroy`. LocalStack persistence is off, so container
shutdown drops any leftover local service data. Keep the committed
`.terraform.lock.hcl` files; only remove `.terraform/` caches and leftover
state.

</details>
