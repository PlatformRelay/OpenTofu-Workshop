# Lab 14 — Security scanners head-to-head — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-2/14-security-scanners/` unless a step says otherwise.

### Step 1 — Scan with Trivy

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

---

### Step 2 — Scan the same tree with Checkov

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

---

### Step 3 — Diff the findings

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

---

### Step 4 — Run the org policy with Conftest

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

---

### Step 5 — Satisfy the org rule (scanners stay red)

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

## Stretch (optional)

Write a second Rego rule under `policy/` that denies any
`aws_s3_bucket_public_access_block` where `block_public_acls` is not `true`.
Run Conftest again before and after flipping that attribute.

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

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-2/14-security-scanners/` prints nothing. This
provider-free lab creates no state, resources, provider downloads, or background
services.

</details>

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

---

## Expected state / output

- Two maintained scanners agree on the loud exposures and disagree on edge rules.
- **Checkov is not the automatic hero** — Trivy covers the same core risks and
  replaces the old `tfsec` habit via `trivy config`.
- Conftest/OPA encodes org-specific promises scanners will not invent.
- Pin scanner versions so lab spoilers stay meaningful; expect rule-pack churn.

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

Re-enter `labs/day-2/14-security-scanners/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

(optional)

Write a second Rego rule under `policy/` that denies any
`aws_s3_bucket_public_access_block` where `block_public_acls` is not `true`.
Run Conftest again before and after flipping that attribute.

```bash
cd labs/day-2/14-security-scanners
tofu plan
```

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

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
