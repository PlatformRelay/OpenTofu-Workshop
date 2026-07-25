---
layout: section-cover
image: /covers/section-26-the-settled-colony.png
day: Day 3
section: '26'
tier: core
---

# Capstone & wrap-up

## The settled colony — one root that ties the three days together

<!--
Say: Close the workshop on one LocalStack multi-module root. Naming, labels, encrypted state, and tofu test land in the same place. Terramate is an optional stretch, not the base path. Then map what you covered against HashiCorp Terraform Associate themes as a design check — not exam prep. (~1 min)
Then: Trace the red line across the three parts.
-->

---
layout: statement
kicker: 'Red line · three days'
---

**Author → protect → test → scale** — one colony, three parts.

Day 1 wrote the contract. Day 2 proved it. Day 3 orchestrated the fleet.
Today you land the colony and check the map.

<!--
Say: Say the red line once. Day 1 authored naming, labels, encryption, and guardrails. Day 2 made contracts executable with tofu test and CI honesty. Day 3 put Terramate above tofu without moving state. The capstone is where those threads meet in one applyable root. (~2 min)
Then: Show the three-part map as cards.
-->

---
layout: topology
clicks: 3
---

<span class="kw-kicker">S26 · red line</span>

# What each day left in the colony

<div class="grid grid-cols-3 gap-3 mt-8">
  <KwCard v-click heading="Day 1 · Author" icon="✍️" variant="accent">
    <code>modules/naming</code> + <code>modules/labels</code>,
    PBKDF2 state encryption, variables / checks.
  </KwCard>
  <KwCard v-click heading="Day 2 · Prove" icon="✅" variant="ok">
    Plan-lane <code>mock_provider</code> + LocalStack apply tests —
    contracts you can re-run.
  </KwCard>
  <KwCard v-click heading="Day 3 · Scale" icon="🛰️" variant="plain">
    Terramate discovers, generates, orders, filters —
    <strong>still does not manage state</strong>.
  </KwCard>
</div>

<p v-click class="mt-8 text-center text-sm opacity-75">
Shipped artifact: <code>examples/capstone/</code> — base path is plain OpenTofu.
</p>

<!--
Say: Three cards, one colony. Naming and labels plus encryption are Day 1. Unit and integration tofu test are Day 2. Terramate stretch is Day 3 and optional — task verify stays green with Terramate absent. Point at examples/capstone as the single source learners will drive. (~3 min)
Then: Tour the root — names, tags, resources.
-->

---
layout: code-walkthrough
---

<span class="kw-kicker">taught artifact · examples/capstone</span>

# Capstone tour — naming + labels + estate

```hcl {1-12|14-26|28-48|50-60}
module "artifacts_name" {
  source        = "../../modules/naming"
  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "artifacts"
  suffix        = var.artifacts_suffix
}

module "labels" {
  source      = "../../modules/labels"
  environment = var.environment
  project     = var.project
  service     = "colony"
  # … criticality, owner, cost_center, taxonomy …
}

resource "aws_s3_bucket" "artifacts" {
  bucket = module.artifacts_name.name
  tags   = module.labels.tags
}

resource "aws_dynamodb_table" "index" { /* … */ }
resource "aws_sqs_queue" "work"       { /* … */ }

check "colony_labels_complete" {
  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project",
                "service", "owner", "cost-center"] :
      contains(keys(module.labels.labels), k)
    ])
    error_message = "capstone label map is missing required keys"
  }
}
```

::notes::

<CodeNote at="1" label="Naming">Three naming calls compose S3 / DynamoDB / SQS names.</CodeNote>
<CodeNote at="2" label="Labels">One shared taxonomy applied to every resource.</CodeNote>
<CodeNote at="3" label="Estate">Bucket + table + queue — small, complete colony.</CodeNote>
<CodeNote at="4" label="Check">S15-style guard — required keys must be present.</CodeNote>

<!--
Say: Walk the composition. Three naming modules, one labels module, three LocalStack resources, and a check that the taxonomy keys exist. This is not a rewrite — learners drive the shipped US-X-CAP artifact. Suffixes are fixed in unit tests so names are known at plan; random on apply. (~3 min)
Then: Show encryption wiring.
-->

---
layout: code-walkthrough
---

<span class="kw-kicker">S05 ↔ capstone · encrypted state</span>

# PBKDF2 → AES-GCM on state and plan

```hcl {1-8|10-16|18-26}
encryption {
  key_provider "pbkdf2" "passphrase" {
    passphrase = var.state_passphrase   # >= 16 chars
  }

  method "aes_gcm" "encrypted" {
    keys = key_provider.pbkdf2.passphrase
  }

  state {
    method = method.aes_gcm.encrypted
    # enforced = true   # flip on once everyone has the key
  }

  plan {
    method = method.aes_gcm.encrypted
  }
}
```

::notes::

<CodeNote at="1" label="PBKDF2">Derive the key from an out-of-band passphrase.</CodeNote>
<CodeNote at="2" label="AES-GCM">Same method for state and plan ciphertext.</CodeNote>
<CodeNote at="3" label="enforced">Optional — refuse plaintext once the team is ready.</CodeNote>

<!--
Say: Same S05 pattern learners already know. Supply TF_VAR_state_passphrase out of band — never commit a real secret. Plan and state both encrypt. enforced stays commented for workshop friction; mention it as the production hardening flip. OpenTofu-native; beyond Associate scope. (~2 min)
Then: Name the two test lanes.
-->

---
layout: comparison
leftHeading: Unit lane · mock
leftBadge: task verify
rightHeading: Integration · LocalStack
rightBadge: verify:integration
---

```text
tests/unit.tftest.hcl
  command = plan
  mock_provider "aws" { alias = "mock" }
  → labels + fixed-suffix names
  → no Docker, no Terramate
```

::right::

```text
tests/integration.tftest.hcl
  command = apply
  → ^s3-colony-d-artifacts-[hex]$
  → tags on live LocalStack resources
  → needs :4566 healthy
```

<!--
Say: Two lanes, one root. Unit proves the contract on a laptop and in CI without Docker. Integration proves names and tags after apply against pinned LocalStack. task verify covers the unit lane; task verify:integration is the live path after lab:up. (~2 min)
Then: Terramate is stretch only.
-->

---
layout: statement
kicker: 'Stretch · optional'
---

Terramate orchestration is a **stretch** — the base path is plain `tofu`.

`examples/capstone/stretch/` points at Day-3 patterns. `task verify` must
stay green when Terramate is **absent**.

<!--
Say: Do not make Terramate a gate for the wrap-up. Learners who finished S20–S23 can peek at stretch/README and sketch storage vs messaging stacks. Everyone else stays on the OpenTofu root. Edge criterion from US-X-CAP: unit lane green without Terramate on PATH. (~1 min)
Then: Hands-on — drive the artifact green, then clean up.
-->

---
layout: lab
lab: labs/day-3/26-capstone.md
duration: 60 min
env: 'localstack ✓ · mock ✓'
---

# Lab — settle the colony

- Tour `examples/capstone/`; break a short passphrase, then fix it.
- Green the unit lane (`task verify` / filtered `tofu test`).
- Apply on LocalStack; prove outputs; full cleanup + panic reset.

<!--
Say: Sixty minutes. Learners consume the shipped artifact — no rewrite. Break→fix on PBKDF2 minimum length, then unit green without Docker, then apply against LocalStack when up. Cleanup is destroy plus task lab:down; panic reset from a half-applied colony must leave no residue. (~60 min)
Then: After the lab — next steps and the Associate design check.
-->

---

<span class="kw-kicker">Next steps</span>

# Keep the colony alive after the workshop

<div class="grid grid-cols-2 gap-4 mt-6">
  <KwCard heading="Practice" variant="accent">
    Re-run <code>examples/capstone/</code> cold: <code>task lab:up</code> →
    unit → apply → <code>task lab:down</code>.
  </KwCard>
  <KwCard heading="Deepen" variant="ok">
    Flip <code>enforced = true</code>; add a second service root; try the
    Terramate stretch split.
  </KwCard>
  <KwCard heading="Docs" variant="plain">
    OpenTofu docs · LocalStack · Terramate docs · this repo’s
    <code>AGENT.md</code> / facilitator runbook.
  </KwCard>
  <KwCard heading="Community" variant="warn">
    OpenTofu CNCF / community channels — vendor-neutral first;
    cloud-vendor docs when you pick a provider.
  </KwCard>
</div>

<!--
Say: Give four exits — practice the same root, harden encryption, read primary docs, join community without a vendor pitch. Point facilitators at the runbook for timing cuts. (~2 min)
Then: Closing design check — Associate coverage map.
-->

---

<span class="kw-kicker">Design check · not exam prep</span>

# Terraform Associate alignment

Coverage map for the **fundamentals**. Themes the workshop deliberately
goes **beyond** (state encryption, provider `for_each`, `-exclude`, Terramate)
are OpenTofu-current — not Associate material. Fuller map, notes, and
consciously out-of-scope themes:
[`docs/associate-alignment.md`](../../docs/associate-alignment.md).

| Associate objective (theme) | Covered by |
| --- | --- |
| IaC concepts / purpose | S01 |
| Terraform/OpenTofu basics & HCL | S02 |
| Core workflow (init/plan/apply/destroy) | S03 |
| State & backends (+ security) | S04, **S05** |
| Variables, outputs, validation | S06, S15 |
| Modules (use, sources, versioning, registry) | S07, S08 |
| Meta-args, lifecycle, refactoring | S09 |
| Testing & validation (native) | S12–S17 |
| Automation & collaboration (HCP/TACO) | S11, S19 |

<!--
Say: Read this as a design check — did we cover the fundamentals an Associate syllabus names? Yes, mapped to sections. It is not a cram sheet and not a promise you will pass an exam. Call out S05 encryption and Day-3 Terramate as beyond-Associate OpenTofu-current material. (~3 min)
Then: Close the workshop on the operating sentence.
-->

---
layout: recap
next: Workshop complete
---

<span class="kw-kicker">recap · settled colony</span>

# Capstone & wrap-up — operating rules

- Red line: **author → protect → test → scale** across three days.
- Capstone = naming + labels + encryption + tests on one LocalStack root.
- Terramate is optional stretch; base path is plain OpenTofu.
- Associate table = coverage map / design check — **not** exam prep.

<p v-click class="mt-8 text-xl font-semibold">Settle the colony. Keep state where <code>tofu</code> put it.</p>

<!--
Say: Final beat. The colony is settled when verify is green and lab:down left no residue. State never moved to an orchestrator. Thank the room; point stragglers at spoilers and the panic-reset path. (~2 min)
Then: Workshop complete.
-->
