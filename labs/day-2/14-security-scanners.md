# Lab 14 — Security scanners head-to-head

| | |
| --- | --- |
| **Section** | S14 — Security & policy scanners |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 35 min |
| **Pinned versions** | Trivy **0.72.0** · Checkov **3.3.0** · Conftest **0.68.2** |

## Objective

Run Trivy and Checkov against the same intentionally-misconfigured module, diff
their findings, then use a Conftest/Rego org policy to catch a `cost_center` tag
rule the scanners miss.

## Prerequisites

- OpenTofu ≥1.9 (`tofu version`).
- Trivy, Checkov, and Conftest on `PATH` (`task setup` / `bash setup/bootstrap.sh`).
- A terminal at the repository root. No credentials, Docker, or cloud account.

Confirm the pinned versions (spoilers below were captured on these builds):

```bash
trivy --version | head -n1
checkov --version
# Conftest may print "dev"; Homebrew's stable for this lab is 0.68.2
brew list --versions conftest 2>/dev/null || conftest --version
```

<details><summary>Solution / expected versions</summary>

```console
Version: 0.72.0
3.3.0
conftest 0.68.2
```

If your patch versions differ, **your counts may differ** — rule packs churn.
Compare finding *IDs and themes*, not exact totals.

</details>

## Files used

- [`labs/day-2/14-security-scanners/messy/main.tf`](./14-security-scanners/messy/main.tf)
- [`labs/day-2/14-security-scanners/policy/cost_center.rego`](./14-security-scanners/policy/cost_center.rego)

The tracked fixture is **fmt-clean** and **insecure on purpose** (adapted from the
S13 messy-fixture pattern — security defects instead of format/type/lint defects):

<!-- source: labs/day-2/14-security-scanners/messy/main.tf -->
```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# Intentionally insecure — planted for Trivy / Checkov comparison (S14).
resource "aws_s3_bucket" "logs" {
  bucket = "workshop-logs-public"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_security_group" "wide_open" {
  name        = "workshop-wide-open"
  description = "Intentionally open for scanner demos"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "workshop-wide-open"
    # Org rule (Conftest): every SG must carry cost_center. Scanners miss this.
  }
}
```

## Step 1 — Scan with Trivy

```bash
cd labs/day-2/14-security-scanners/messy
trivy config --severity HIGH,CRITICAL --format table --exit-code 1 .
```

**Task:** How many failures? Which finding is CRITICAL? Does anything mention
`cost_center`? Why does the command need `--exit-code 1`?

<details><summary>Solution / expected failure (Trivy 0.72.0)</summary>

Trivy prints the findings and exits **1** because of `--exit-code 1` (CI-style
gate). Without that flag, Trivy 0.72.0 still prints the same report but exits
**0** — findings alone do not fail the process.

Summary excerpt:

```console
main.tf (terraform)
===================
Tests: 7 (SUCCESSES: 0, FAILURES: 7)
Failures: 7 (HIGH: 6, CRITICAL: 1)
```

Finding IDs from this pin:

| ID | Severity | Theme |
| --- | --- | --- |
| AWS-0086 | HIGH | public ACLs not blocked |
| AWS-0087 | HIGH | public policies not blocked |
| AWS-0091 | HIGH | public ACLs not ignored |
| AWS-0093 | HIGH | public buckets not restricted |
| AWS-0104 | **CRITICAL** | unrestricted egress `0.0.0.0/0` |
| AWS-0107 | HIGH | unrestricted ingress (SSH) |
| AWS-0132 | HIGH | bucket without customer-managed key |

Representative CRITICAL excerpt:

```console
AWS-0104 (CRITICAL): Security group rule allows unrestricted egress to any IP address.
────────────────────────────────────────
 main.tf:46
   via main.tf:42-47 (egress)
    via main.tf:30-53 (aws_security_group.wide_open)
```

Nothing mentions `cost_center`.

</details>

<details><summary>Your counts may differ (Trivy)</summary>

Rule packs and the Trivy checks bundle update independently of the binary
version. Treat the table above as a **theme checklist**, not a grade. If you see
six or eight failures instead of seven, keep going — Step 3 is about the diff
shape, not matching a golden total.

</details>

## Step 2 — Scan the same tree with Checkov

Still inside `messy/`:

```bash
checkov -d . --framework terraform --compact --quiet
```

**Task:** How many failed checks? Which Checkov-only theme did Trivy skip? Still
no `cost_center`?

<details><summary>Solution / expected failure (Checkov 3.3.0)</summary>

```console
terraform scan results:

Passed checks: 5, Failed checks: 7, Skipped checks: 0

Check: CKV_AWS_53: "Ensure S3 bucket has block public ACLS enabled"
	FAILED for resource: aws_s3_bucket_public_access_block.logs
	File: /main.tf:21-28
Check: CKV_AWS_54: "Ensure S3 bucket has block public policy enabled"
	FAILED for resource: aws_s3_bucket_public_access_block.logs
	File: /main.tf:21-28
Check: CKV_AWS_55: "Ensure S3 bucket has ignore public ACLs enabled"
	FAILED for resource: aws_s3_bucket_public_access_block.logs
	File: /main.tf:21-28
Check: CKV_AWS_56: "Ensure S3 bucket has 'restrict_public_buckets' enabled"
	FAILED for resource: aws_s3_bucket_public_access_block.logs
	File: /main.tf:21-28
Check: CKV_AWS_24: "Ensure no security groups allow ingress from 0.0.0.0:0 to port 22"
	FAILED for resource: aws_security_group.wide_open
	File: /main.tf:30-53
Check: CKV_AWS_23: "Ensure every security group and rule has a description"
	FAILED for resource: aws_security_group.wide_open
	File: /main.tf:30-53
Check: CKV_AWS_382: "Ensure no security groups allow egress from 0.0.0.0:0 to port -1"
	FAILED for resource: aws_security_group.wide_open
	File: /main.tf:30-53
```

(Guides/URLs follow each check in the full CLI output; omitted here for length.)

Checkov exits non-zero. Nothing mentions `cost_center`.

</details>

<details><summary>Your counts may differ (Checkov)</summary>

Checkov rule IDs and pass/fail splits move between minor releases. A newer
3.3.x may add or retire a check against this same fixture — record the IDs you
actually see for the diff step.

</details>

## Step 3 — Diff the findings

**Task:** Fill the three buckets from *your* runs:

1. **Shared** — both tools complain about roughly the same exposure.
2. **Trivy-only** — present in Step 1, absent in Step 2.
3. **Checkov-only** — present in Step 2, absent in Step 1.

<details><summary>Solution / expected observation (pinned versions)</summary>

| Bucket | Evidence on 0.72.0 / 3.3.0 |
| --- | --- |
| **Shared** | Disabled S3 public-access block (four flags) · SSH open to `0.0.0.0/0` · unrestricted egress |
| **Trivy-only** | **AWS-0132** — bucket without a customer-managed key |
| **Checkov-only** | **CKV_AWS_23** — every security-group *rule* needs a description (the `egress` block has none) |

Neither tool encodes the org tag rule. That is not a scanner bug — it is why
Conftest exists.

</details>

## Step 4 — Run the org policy with Conftest

Inspect the shipped Rego, then test the same `main.tf`:

<!-- source: labs/day-2/14-security-scanners/policy/cost_center.rego -->
```rego
package main

import future.keywords.contains
import future.keywords.if

# Org policy: every aws_security_group must carry a cost_center tag.
# Generic scanners do not encode this rule — Conftest/OPA does.
deny contains msg if {
	some name
	resource := input.resource.aws_security_group[name][_]
	not resource.tags.cost_center
	msg := sprintf("aws_security_group.%s missing required tag cost_center", [name])
}
```

```bash
conftest test --no-color -p ../policy --parser hcl2 main.tf
```

**Task:** Confirm Conftest fails on `cost_center` while Steps 1–2 never mentioned
that tag.

<details><summary>Solution / expected failure (Conftest 0.68.2)</summary>

```console
FAIL - main.tf - main - aws_security_group.wide_open missing required tag cost_center

1 test, 0 passed, 0 warnings, 1 failure, 0 exceptions
```

Exit status is non-zero. This is the org rule scanners missed.

</details>

## Step 5 — Satisfy the org rule (scanners stay red)

Add the required tag, keep the insecure networking for now, and re-run Conftest:

```hcl
  tags = {
    Name        = "workshop-wide-open"
    cost_center = "platform-workshop"
  }
```

```bash
tofu fmt main.tf
conftest test --no-color -p ../policy --parser hcl2 main.tf
```

**Task:** Conftest should pass. Re-run one scanner and confirm it still fails on
the planted exposure.

<details><summary>Solution / expected output</summary>

Conftest:

```console
1 test, 1 passed, 0 warnings, 0 failures, 0 exceptions
```

Trivy (still red on exposure — exit 1 with `--exit-code 1`):

```bash
trivy config --severity HIGH,CRITICAL --format table --exit-code 1 .
```

You should still see failures such as AWS-0104 / AWS-0107 and the public-access
block findings, and the process exits **1**. Org policy green ≠ misconfig green.

</details>

## Expected observations

- Two maintained scanners agree on the loud exposures and disagree on edge rules.
- **Checkov is not the automatic hero** — Trivy covers the same core risks and
  replaces the old `tfsec` habit via `trivy config`.
- Conftest/OPA encodes org-specific promises scanners will not invent.
- Pin scanner versions so lab spoilers stay meaningful; expect rule-pack churn.

## Cleanup / panic reset

Restore the deliberately insecure tracked fixture for the next learner:

```bash
cd ../../../../
git restore -- labs/day-2/14-security-scanners/messy/main.tf
git status --short -- labs/day-2/14-security-scanners/
```

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-2/14-security-scanners/` prints nothing. This
provider-free lab creates no state, resources, provider downloads, or background
services.

</details>

## Stretch (optional)

Write a second Rego rule under `policy/` that denies any
`aws_s3_bucket_public_access_block` where `block_public_acls` is not `true`.
Run Conftest again before and after flipping that attribute.

<details><summary>Solution / starting point</summary>

```rego
package main

import future.keywords.contains
import future.keywords.if

deny contains msg if {
	some name
	block := input.resource.aws_s3_bucket_public_access_block[name][_]
	block.block_public_acls != true
	msg := sprintf("aws_s3_bucket_public_access_block.%s must set block_public_acls=true", [name])
}
```

Remove the stretch file (or restore the directory) when finished so the next
learner starts from the shipped single-rule policy:

```bash
git restore -- labs/day-2/14-security-scanners/policy
```

</details>
