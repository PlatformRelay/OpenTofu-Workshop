---
layout: section-cover
image: /covers/section-14-the-gauntlet-of-scanners.png
day: Day 2
section: '14'
tier: core
---

# Security & policy scanners

## Choose tools by maintenance, coverage, and who owns policy

<!--
Say: Static analysis caught format, types, and lint. Security scanners look for
misconfigurations that become exposure; policy engines encode organization rules
the scanner authors never heard of. This section is a head-to-head — Checkov is
not the default hero. (~1 min)
Then: Start with the decision axes, not a favourite brand.
-->

---
layout: statement
kicker: 'The reframe'
---

Pick scanners by **coverage, speed, policy language, ecosystem, and maintenance** —
not by last year's blog post.

<!--
Say: Tool lists rot. The useful skill is comparing axes: what does it catch, how
fast is it locally, how do you express custom policy, what ecosystem surrounds
it, and is the project still alive. Maintenance status is a first-class axis —
adopting an archived scanner is a self-inflicted incident. (~2 min)
Then: Walk the 2026 field on those axes.
-->

---

<span class="kw-kicker">the field · 2026</span>

# Head-to-head — and one strike-through

<div class="kw-stamp">
Facts verified 2026-08-25 — re-check maintenance status before you ship a standard.
</div>

<table class="kw-scanner-table mt-3">
  <thead>
    <tr>
      <th>Tool</th>
      <th>Coverage</th>
      <th>Speed</th>
      <th>Policy language</th>
      <th>Ecosystem</th>
      <th>Maintenance</th>
    </tr>
  </thead>
  <tbody>
    <tr v-click>
      <td><strong>Trivy</strong> <code>config</code></td>
      <td>IaC misconfig (+ CVE elsewhere)</td>
      <td>Fast local CLI</td>
      <td>Built-in checks; OPA-friendly adjacent</td>
      <td>Aqua; absorbed <strong>tfsec</strong> (2023)</td>
      <td class="cell-yes">ALIVE</td>
    </tr>
    <tr v-click>
      <td><strong>Checkov</strong></td>
      <td>Broad IaC ruleset</td>
      <td>Fast local CLI</td>
      <td>YAML / Python custom checks</td>
      <td>Prisma Cloud / Apache-2.0 CLI</td>
      <td class="cell-yes">ALIVE</td>
    </tr>
    <tr v-click>
      <td><strong><s>Terrascan</s></strong></td>
      <td><s>IaC policies</s></td>
      <td><s>—</s></td>
      <td><s>Rego</s></td>
      <td><s>Tenable</s></td>
      <td class="cell-dead">ARCHIVED 2025-11-20</td>
    </tr>
    <tr v-click>
      <td><strong>KICS</strong></td>
      <td>Multi-IaC queries</td>
      <td>CLI / CI</td>
      <td>Rego queries</td>
      <td>Checkmarx OSS</td>
      <td class="cell-yes">ALIVE</td>
    </tr>
    <tr v-click>
      <td><strong>Snyk IaC</strong></td>
      <td>Misconfig + product surface</td>
      <td>CLI / SaaS</td>
      <td>Product policy + custom</td>
      <td>Snyk commercial ecosystem</td>
      <td class="cell-yes">ALIVE</td>
    </tr>
  </tbody>
</table>

<style>
.kw-stamp {
  display: inline-block;
  margin-top: 0.25rem;
  padding: 0.35rem 0.7rem;
  border: 1px dashed var(--kw-warn);
  border-radius: var(--kw-radius-sm);
  color: var(--kw-warn);
  font-size: 0.72rem;
  line-height: 1.3;
}
.kw-scanner-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.72rem;
}
.kw-scanner-table th,
.kw-scanner-table td {
  border: 1px solid var(--kw-border);
  padding: 0.35rem 0.5rem;
  text-align: left;
  vertical-align: top;
}
.kw-scanner-table thead th {
  background: color-mix(in srgb, var(--kw-fg) 6%, transparent);
  font-weight: 600;
}
.kw-scanner-table td.cell-yes { color: var(--kw-ok); font-weight: 600; }
.kw-scanner-table td.cell-dead { color: var(--kw-danger); font-weight: 700; }
</style>

<!--
Say: Click through the rows. Trivy config is the successor to tfsec — teach
`trivy config`, not the superseded binary. Checkov remains a strong broad ruleset.
Terrascan is the cautionary tale: archived 2025-11-20 — strike it through out
loud so nobody standardises on a read-only repo. KICS and Snyk IaC stay in the
comparison set. (~4 min)
Then: Separate scanning from organization policy.
-->

---
layout: comparison
---

<span class="kw-kicker">superseded &amp; archived · don't adopt either</span>

# Two load-bearing facts

::left::

### tfsec → Trivy

- Aqua merged **tfsec** into Trivy (2023)
- Command today: **`trivy config`**
- Still published (v1.28.14, 2025-05-02) but superseded — new material should not teach `tfsec`

::right::

### Terrascan → archived

- **Archived 2025-11-20** (read-only)
- Last meaningful release trail went cold in 2024
- Do not pick a dead tool as your standard

<p v-click class="mt-5 text-sm opacity-75">Maintenance status beats a long feature checklist.</p>

<!--
Say: Say these two facts slowly — they are the workshop's "don't teach the superseded or archived
tool" pair. If someone still has tfsec in a pipeline, the migration path is
Trivy config. If someone proposes Terrascan in 2026, the answer is no. (~2 min)
Then: Policy engines sit beside scanners, not inside every one of them.
-->

---
layout: comparison
---

<span class="kw-kicker">policy · org rules vs product rules</span>

# Scanners miss what only your org cares about

::left::

### OPA / Conftest

- CNCF Graduated OPA; Conftest wraps Rego for config
- Portable across CI and TACOs
- You write the rule: tags, naming, approved CIDRs

::right::

### Sentinel

- **HashiCorp products only** — HCP Terraform / Terraform Enterprise, Vault, Nomad
- Proprietary policy language
- Fine inside those products — not a portable default

<p v-click class="mt-5 text-sm opacity-75">Generic misconfig ≠ cost_center must be present.</p>

<!--
Say: Built-in scanner rules encode common cloud hygiene. Organization policy —
required tags, approved module sources, region allow-lists — belongs in Rego
via Conftest/OPA when you want portability. Sentinel is real and useful, but it
is tied to HashiCorp's own products; do not present it as the OpenTofu-first
default. (~3 min)
Then: Land the 2026 recommendation in one sentence.
-->

---
layout: statement
kicker: '2026 recommendation'
---

Lean **Trivy for scanning** + **Conftest / OPA for org policy**.

Checkov remains an excellent second opinion — not the automatic default.

<!--
Say: This is a lean default, not a religion. Trivy gives a fast, maintained
misconfig scan (and replaces the tfsec habit). Conftest gives you Rego for rules
scanner authors will never ship. Run Checkov when you want a second ruleset or
already live in that ecosystem — just don't anoint it by inertia. (~2 min)
Then: Prove the point on one deliberately bad module.
-->

---
layout: code-annotated
---

<span class="kw-kicker">same module · two scanners</span>

# Planted exposure, one workdir

```hcl {none|17-19|21-28|30-47|49-52}
terraform {
  required_version = ">= 1.8"

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

::notes::

<CodeNote at="1" label="Bucket">No encryption resource — Trivy flags CMK hygiene.</CodeNote>
<CodeNote at="2" label="Public">All four public-access blocks disabled on purpose.</CodeNote>
<CodeNote at="3" label="Network">SSH and egress open to 0.0.0.0/0 — both scanners fire.</CodeNote>
<CodeNote at="4" label="Org gap">Missing cost_center — scanners stay quiet; Conftest will not.</CodeNote>

<!--
Say: This is the lab fixture — formatted cleanly so repo fmt gates stay green,
but insecure by design. Walk the four planted classes: bare bucket, open public
access block, wide-open security group, and the org tag gap. Emphasize that the
tag gap is intentional: it is the Conftest beat. (~3 min)
Then: Show how the two scanners disagree at the margins.
-->

---
layout: comparison
---

<span class="kw-kicker">findings diff · same tree</span>

# Overlap is large; edges differ

::left::

### Trivy `config` (0.72.0)

```console
Failures: 7 (HIGH: 6, CRITICAL: 1)
AWS-0086 … public ACLs
AWS-0104 CRITICAL unrestricted egress
AWS-0107 unrestricted ingress
AWS-0132 bucket CMK encryption
```

::right::

### Checkov (3.3.0)

```console
Failed checks: 7
CKV_AWS_53…56 public access block
CKV_AWS_24 SSH 0.0.0.0/0
CKV_AWS_382 unrestricted egress
CKV_AWS_23 every rule needs a description
```

<p v-click class="mt-5 text-sm opacity-75">Shared: public S3 + open SG. Unique: Trivy CMK · Checkov rule descriptions.</p>

<!--
Say: Neither tool is wrong — they encode different rule packs. Trivy called the
CMK encryption gap; Checkov insisted every SG rule has a description. Counts
will drift as rule packs update — pin versions in the lab and expect churn.
Neither reported the missing cost_center tag. (~3 min)
Then: Close that gap with Rego.
-->

---
layout: code-annotated
---

<span class="kw-kicker">conftest · org policy</span>

# Rego catches what scanners ignore

```text {1-4|6-7|8-13}
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

::notes::

<CodeNote at="1" label="Package">Conftest loads package main denies by default.</CodeNote>
<CodeNote at="2" label="Intent">Comment documents the org rule scanners will not invent.</CodeNote>
<CodeNote at="3" label="Deny">Modern Rego uses contains/if; fail when the tag is absent.</CodeNote>

<!--
Say: This is a tiny, readable org rule. Parse HCL with --parser hcl2, deny when
cost_center is missing. After you add the tag, Conftest goes green while Trivy
and Checkov still complain about the real exposure — that split is the teaching
point. (~3 min)
Then: Put Trivy, Checkov, and Conftest in the learners' hands.
-->

---
layout: lab
duration: 35 min
---

<span class="kw-kicker">lab · scan → diff → policy</span>

# Two scanners, one org rule

<LabCallout lab="labs/day-2/14-security-scanners.md" duration="35 min" />

1. Run **Trivy** and **Checkov** on the same messy module; pin versions.
2. Diff shared findings vs unique edges; note the missing `cost_center` gap.
3. Run **Conftest** with the shipped Rego; then add the tag and re-check.

<!--
Say: Thirty-five minutes, no Docker. Spoilers contain verbatim output from the
pinned versions — if counts differ, it is rule churn, not learner error. Cleanup
restores the fixture for the next person. (~35 min)
Then: Recap the lean default and hand off to native tests.
-->

---
layout: recap
next: 'S16 · Native tofu test'
---

<span class="kw-kicker">recap · lean default</span>

# Scan with Trivy; encode org policy in Rego

- Compare scanners on **coverage / speed / policy / ecosystem / maintenance**.
- **tfsec → Trivy** (superseded); **Terrascan → archived** — teach neither.
- **Checkov** is a strong peer, not the automatic hero.
- **2026 lean default:** Trivy for scanning + Conftest/OPA for org policy.
- Sentinel stays inside HashiCorp's products; portable policy prefers OPA.

<p v-click class="mt-8 text-xl font-semibold">Misconfig scanners ≠ your organization's rules.</p>

<!--
Say: Leave them with a decision rule, not a brand loyalty. Maintain the tools,
diff two scanners when the blast radius is high, and put org-specific promises
in Rego. Next we move up the pyramid into native tofu test. (~2 min)
Then: S16 · Native tofu test.
-->
