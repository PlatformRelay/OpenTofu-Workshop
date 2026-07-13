---
theme: ./theme
title: Template gallery & design system
info: |
  The OpenTofu workshop deck's design system, rendered as slides: master theme,
  reusable layouts and components, HCL code-annotation patterns, and the
  block-glyph icon set. Not workshop content — the toolkit every section reuses.
layout: cover
meta: slidev-theme-opentofu-workshop · dark · purple accent · brand yellow
---

# OpenTofu Practitioner Workshop

Deck design system — master theme, reusable layouts, and the code-first patterns
every section is built from.

<div class="flex gap-2 mt-6">
  <KwChip variant="accent">code-first</KwChip>
  <KwChip>HCL that grows</KwChip>
  <KwChip>vendor-neutral</KwChip>
  <KwChip variant="ok">open source</KwChip>
</div>

---

<span class="kw-kicker">About this deck</span>

# What this gallery is

This is **not workshop content** — it is the deck's design system, rendered as slides:

- One slide per reusable **layout** — cover, section cover, agenda, statement,
  code walkthrough, annotated code, comparison, topology, lab, recap.
- The **HCL code-annotation patterns**: click-synced line highlights with a note
  rail, magic-move manifests that grow field-by-field, and floating overlay callouts.
- The **`IacIcon` block-glyph set** — one badge per HCL construct.

Curriculum sections (`pages/SNN-topic/`) import these layouts and components —
they never re-implement a pattern per slide.

---
layout: statement
kicker: 'Layout: statement — one big idea per slide'
---

Infrastructure as Code is a **desired-state** engine: you declare what should
exist, `tofu` computes the diff, and an execution **plan** closes the gap.

Everything in this workshop — modules, state, testing, Terramate — is this one
sentence wearing different HCL.

---
layout: agenda
heading: Part 1 — Terraform/OpenTofu foundations
kicker: 'Layout: agenda'
---

- **IaC & the OpenTofu fork** — why, and what changed in 2023 <em>· 30 min</em>
- **HCL building blocks** — resource, variable, output, module <em>· 40 min</em>
- **The core workflow** — init · plan · apply · destroy <em>· 35 min</em>
- **State** 🗺️ — the map of what you built <em>· 30 min</em>
- **State encryption** 🔒 — OpenTofu's client-side headline <em>· 30 min</em>
- **Naming & labelling module** — the flagship, tested <em>· 45 min</em>
- **Labs after every block** 🧪 — LocalStack, no cloud bill <em>· ~50%</em>

---
layout: section-cover
image: /covers/placeholder-section.svg
day: Day 1
section: '05'
---

# State encryption

The smallest slide with the biggest payoff — and the layout every section opens with.

---

<span class="kw-kicker">Layout: default + KwCard grid + IacIcon glyphs</span>

# HCL in three kinds of block

<div class="kw-cols-3 mt-4">
  <v-click at="1">
    <KwCard heading="Resources" kind="resource">
      <strong>Create.</strong> The things that exist — a bucket, a role, a queue.
      Each maps to one real (or emulated) API object.
    </KwCard>
  </v-click>
  <v-click at="2">
    <KwCard heading="Variables & outputs" kind="variable">
      <strong>Parameterise.</strong> Inputs that shape a module and outputs that
      hand values to the next one.
    </KwCard>
  </v-click>
  <v-click at="3">
    <KwCard heading="Modules" kind="module" variant="plain">
      <strong>Compose.</strong> A folder of blocks with a contract — the unit of
      reuse the whole workshop builds toward.
    </KwCard>
  </v-click>
</div>

<div v-click="4" class="mt-6 kw-muted text-sm">

The rest of Part 1 walks *down* this picture: declare resources, wrap them in
modules, and keep the **state** that remembers what you made.

</div>

---
layout: code-walkthrough
heading: A resource grows — named and labelled
lab: labs/day-1/08-naming.md
---

````md magic-move
```hcl
resource "aws_s3_bucket" "assets" {
  bucket = "assets"
}
```

```hcl
module "naming" {
  source        = "../../modules/naming"
  resource_type = "aws_s3_bucket"
  project       = "shopfront"
  environment   = "dev"
}

resource "aws_s3_bucket" "assets" {
  bucket = module.naming.name # s3-shopfront-d-...-a1f3
}
```

```hcl
module "naming" {
  source        = "../../modules/naming"
  resource_type = "aws_s3_bucket"
  project       = "shopfront"
  environment   = "dev"
}

module "labels" {
  source      = "../../modules/labels"
  project     = "shopfront"
  environment = "dev"
  criticality = "high"
  service     = "storefront"
  owner       = "platform@example.com"
  cost_center = "eng-1201"
}

resource "aws_s3_bucket" "assets" {
  bucket = module.naming.name
  tags   = module.labels.tags
}
```
````

---
layout: code-annotated
heading: State encryption — read the block, click by click
lab: labs/day-1/05-state-encryption.md
---

```hcl {none|1-2|3-6|7-11|all}
terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase # 16+ chars
    }
    method "aes_gcm" "secure" {
      keys = key_provider.pbkdf2.passphrase
    }
    state { method = method.aes_gcm.secure }
    plan  { method = method.aes_gcm.secure }
  }
}
```

::notes::

<CodeNote at="1" label="terraform.encryption">
  A first-class block in OpenTofu 1.7+. No Terraform equivalent — the headline
  differentiator.
</CodeNote>

<CodeNote at="2" label="key_provider &quot;pbkdf2&quot;">
  Derives a key from a passphrase — zero cloud dependency, perfect for a lab.
  Swap for <code>aws_kms</code> / <code>gcp_kms</code> in production.
</CodeNote>

<CodeNote at="3" label="method &quot;aes_gcm&quot;" variant="ok">
  Authenticated encryption. The state and plan files are ciphertext at rest.
</CodeNote>

<CodeNote at="4" label="state + plan" variant="warn">
  Encrypt <strong>both</strong>. A plan file leaks as much as state — it contains
  resolved values.
</CodeNote>

---
layout: comparison
heading: Who runs your code?
leftHeading: HCP Terraform
rightHeading: OpenTofu + independent TACO
leftBadge: 'Terraform only'
rightBadge: 'OpenTofu-first'
---

- Runs **Terraform** (BUSL) exclusively
- Policy: **Sentinel** (proprietary) + OPA
- State managed for you; per-resource pricing
- One vendor, one roadmap

::right::

- Spacelift · env0 · Scalr · Terrateam · Digger
- Every one **runs OpenTofu**; most champion it
- Policy: **OPA/Conftest** (open)
- Self-host or SaaS; bring-your-own-state options

---
layout: two-cols-code
heading: Plan on the left, mental model on the right
---

```console
$ tofu plan
OpenTofu will perform the following actions:

  # aws_s3_bucket.assets will be created
  + resource "aws_s3_bucket" "assets" {
      + bucket = "s3-shopfront-d-euw1-a1f3"
      + tags   = {
          + "environment" = "dev"
          + "criticality" = "high"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

::right::

<div class="kw-flow mt-8">
  <span class="kw-obj">config (.tf)</span>
  <span class="kw-flow-arrow">→</span>
  <span class="kw-obj kw-obj--warn">plan (diff)</span>
  <span class="kw-flow-arrow">→</span>
  <span class="kw-obj kw-obj--ok">apply</span>
</div>

<div class="mt-6 kw-muted text-sm">

`plan` is the diff between your **config** and the **state**. Nothing changes
until you `apply` it. Read every plan like a code review.

</div>

---

<span class="kw-kicker">Pattern: CodeCallout — label a risky line in place</span>

# Spot the anti-pattern

```hcl
provider "aws" {
  access_key = "AKIA................"
  secret_key = "wJalr................"
  region     = "eu-west-1"
}
```

<CodeCallout at="1" top="28%" right="6%" width="18rem" label="hardcoded credentials" variant="danger">
  Secrets in <code>.tf</code> end up in git and state. Use environment auth or a
  provider credential source — never literals.
</CodeCallout>

---
layout: topology
heading: Module composition
caption: A root module wires small, tested modules — the unit of reuse.
---

<div class="kw-flow" style="justify-content:center; gap:1rem;">
  <div class="kw-panel" style="padding:0.8rem 1rem;">
    <div class="kw-kicker">root</div>
    <span class="kw-obj mt-2">examples/naming-labels-demo</span>
  </div>
  <span class="kw-flow-arrow">→</span>
  <div class="kw-cols-2" style="gap:0.8rem;">
    <span class="kw-obj kw-obj--ok"><IacIcon kind="module" variant="unlabeled" size="1rem" /> modules/naming</span>
    <span class="kw-obj kw-obj--ok"><IacIcon kind="module" variant="unlabeled" size="1rem" /> modules/labels</span>
  </div>
</div>

<div class="mt-8 kw-muted text-sm text-center">

Each leaf module ships its own `*.tftest.hcl` — the root just composes contracts.

</div>

---
layout: lab
lab: labs/day-1/05-state-encryption.md
duration: 25 min
env: 'localstack ✓ · mock ✓ · real-aws (optional)'
---

# Lab — encrypt your state

Take an unencrypted local state, add a `terraform { encryption }` block with a
PBKDF2 passphrase, migrate, and prove the file on disk is ciphertext.

Every task ships a `<details>` spoiler. Panic reset is always `task lab:down`.

---
clicks: 4
---

<span class="kw-kicker">Component: PlanApplyFlow — the core workflow, click-stepped</span>

# init → plan → apply, and the state it writes

<PlanApplyFlow :step="$clicks" class="mt-10" />

<div v-click="4" class="mt-8 kw-muted text-sm text-center">

Each click lights the next stage: **config** is what you declare, **plan** is the
diff, **apply** converges reality, and **state** records what now exists. Bind
`:step="$clicks"` and the mental model builds itself as you talk.

</div>

<!--
Say: This is the one diagram behind Part 1. Click through it: config is the .tf
you write, plan is the diff tofu computes, apply converges reality to match, and
state is the record it keeps. Four clicks, four stages — the whole desired-state
loop in one visual. (~2 min)
Then: the same click-stepped idea powers the testing pyramid, next.
-->

---
clicks: 4
---

<span class="kw-kicker">Component: TestPyramid — Part 2's reusable visual</span>

# The testing pyramid, built bottom-up

<TestPyramid
  :step="$clicks"
  :static-tools="['tofu fmt', 'tofu validate', 'tflint']"
  :unit-tools="['tofu test (mock)']"
  :integration-tools="['tofu test + LocalStack']"
  :e2e-tools="['real cloud (optional)']"
  class="mt-8"
/>

<div v-click="4" class="mt-6 kw-muted text-sm text-center">

Cheap and many at the **static** base; slow and few at the **e2e** tip. Each
layer takes its own tool labels via props — S12 and S18 reuse this exact
component with their own sets.

</div>

<!--
Say: Every testing discussion in Part 2 hangs off this one pyramid. Build it
bottom-up: static checks first — fmt, validate, tflint — then mock unit tests,
then integration against LocalStack, and finally optional end-to-end on real
cloud. Wide and fast at the base, narrow and slow at the tip. (~2 min)
Then: that closes the component tour — on to the recap.
-->

---
layout: recap
heading: Design system — recap
story: 'Ten layouts, a component kit with click-stepped diagrams, one glyph set — reused, never re-invented.'
next: 'Next: the section library under pages/SNN-topic/'
---

- **Layouts** carry structure: cover, section-cover, agenda, statement,
  code-walkthrough, code-annotated, comparison, two-cols-code, topology, lab, recap.
- **Components** carry meaning: `KwCard`, `KwChip`, `CodeNote`, `CodeCallout`,
  `IacIcon`, `ArchBox`, and click-stepped diagrams `PlanApplyFlow`, `TestPyramid`.
- **magic-move** grows HCL; **CodeNote** explains it; **CodeCallout** warns on it.

---

<span class="kw-kicker">Reference: IacIcon block-glyph set</span>

# One badge per HCL construct

<div class="kw-cols-3 mt-4 text-center">
  <div><IacIcon kind="resource" size="3.4rem" /></div>
  <div><IacIcon kind="variable" size="3.4rem" /></div>
  <div><IacIcon kind="output" size="3.4rem" /></div>
  <div><IacIcon kind="module" size="3.4rem" /></div>
  <div><IacIcon kind="provider" size="3.4rem" /></div>
  <div><IacIcon kind="state" size="3.4rem" /></div>
  <div><IacIcon kind="encryption" size="3.4rem" /></div>
  <div><IacIcon kind="test" size="3.4rem" /></div>
  <div><IacIcon kind="stack" size="3.4rem" /></div>
</div>

<div class="mt-6 kw-muted text-sm">

Use a glyph wherever a slide names a <strong>specific</strong> construct; keep
emoji for conceptual/decorative cards. Over-conversion is a defect.

</div>

---

<span class="kw-kicker">Convention: presenter notes on every content slide</span>

# This slide has presenter notes

Open **presenter mode** (press `p`, or the toolbar) and you'll see facilitator
notes for this slide in the side panel — they never render here.

- Notes live in the **last HTML comment** in a slide, at the very end of its markdown.
- Each note carries three things: **what to say · a timing cue · the transition**.
- Every content slide in a section gets one — see `AGENT.md`, DoD item 8.

<!--
Say: This is the notes convention itself, demonstrated. If you're in presenter
mode right now, this text is what you see in the side panel while the audience
sees only the slide. Author it as the LAST HTML comment in the slide, after all
content, and give it three parts: what to say, a timing cue, and the transition.
(~1 min)
Then: close on the reference statement — everything here is open and reusable.
-->

---
layout: statement
kicker: 'Reference'
---

Everything here is open source and vendor-neutral.

Copy a layout, fill it with HCL, and the section looks like it belongs.
