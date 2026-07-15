---
layout: section-cover
image: /covers/placeholder-section.svg
day: Day 1
section: '06'
tier: core
---

# Variables, validation & types

Hardcoded values don't scale. Typed, validated input variables turn one config
into a reusable, self-checking module — and set up Part 2's validation story.

<!--
Say: Frame the section. So far every value we've written has been hardcoded into
the resource. That doesn't scale — the moment you want the same config for dev and
prod you're copy-pasting. Variables fix that, and OpenTofu's type system plus
validation blocks make them self-checking, so a bad input fails fast with a clear
message instead of a broken apply. This is also the on-ramp to the deeper
validation story in the next section. (~1 min)
Then: "Let's start with what a variable actually is."
-->

---
layout: statement
kicker: 'The shift'
---

A **variable** is a typed input; an **output** is a value you export.

Together they turn a config into a **module** — something you can reuse with
different inputs and read results back from.

<!--
Say: Land the mental model. A variable is a typed input into your config; an
output is a value you publish back out. The pair is what turns a flat config into
a reusable module: callers feed inputs, read outputs, and never touch the guts.
Everything in this section hangs off that input/output frame. (~2 min)
Then: "Inputs are only useful if they're typed — here are the three type families."
-->

---

<span class="kw-kicker">Type families</span>

# Three kinds of variable type

<div class="kw-cols-3 mt-4">
  <KwCard heading="Primitive" kind="variable">
    <strong><code>string</code>, <code>number</code>, <code>bool</code>.</strong>
    The scalars. A defaultless one is <em>required</em>.
  </KwCard>
  <KwCard heading="Collection" kind="variable" variant="ok">
    <strong><code>list()</code>, <code>set()</code>, <code>map()</code>.</strong>
    Many values of <em>one</em> element type.
  </KwCard>
  <KwCard heading="Structural" kind="variable" variant="warn">
    <strong><code>object({…})</code>, <code>tuple([…])</code>.</strong>
    Named fields, each with its <em>own</em> type.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Prefer a single typed **`object`** over a scatter of loose variables — one input,
one shape, validated as a whole. That's what the lab's `service` variable does.

</div>

<!--
Say: Three families. Primitives are the scalars — string, number, bool — and a
primitive with no default is a required input. Collections hold many values of one
element type — list, set, map. Structural types hold named fields each with its
own type — object and tuple. Then the click reveal makes the recommendation:
reach for one typed object over a pile of loose variables, because you get one
input with one validated shape — exactly the service object the lab builds. (~3 min)
Then: "Let's grow that object variable field by field, then guard it."
-->

---
layout: two-cols-code
heading: A typed object variable — then guard it
lab: labs/day-1/06-variables.md
---

````md magic-move
```hcl
# 1. A loose, untyped input — anything goes.
variable "service" {
  type = any
}
```

```hcl
# 2. A typed object: named fields, each with its own type.
variable "service" {
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}
```

```hcl
# 3. Guard it — a validation that reads ANOTHER variable.
variable "service" {
  type = object({
    name     = string
    tier     = string
    replicas = number
  })

  validation {
    condition     = !(var.environment == "prod" && var.service.replicas < 2)
    error_message = "A prod service needs at least 2 replicas."
  }
}
```
````

::right::

<div class="mt-2">
  <KwCard heading="type = object({…})" kind="variable">
    <strong>Named fields, each typed.</strong> Callers must pass every field with
    the right type, or the plan fails — no more <code>any</code>.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="validation {}" kind="validation" variant="warn">
    <strong>A guard clause.</strong> False <code>condition</code> ⇒ the plan stops
    with your message, before any resource is touched. This one reads
    <code>var.environment</code> too — <strong>cross-variable</strong>, an
    OpenTofu <strong>1.9</strong> feature.
  </KwCard>
  </div>
</div>

<!--
Say: This is the magic-move heart of the section. Grow the variable in three
moves. First a loose type = any input — anything goes, no safety. Then a typed
object: named fields, each with its own type, so callers must pass every field
correctly or the plan fails. Then the payoff move: add a validation block, a guard
clause that stops the plan with your message before any resource is touched — and
critically, its condition reads var.environment, not just var.service. Reasoning
across two variables like that is the OpenTofu 1.9 cross-variable feature. The HCL
here is illustrative for reading; the lab's tracked file is the byte-exact source.
(~6 min)
Then: "So who supplies these values, and who wins when two sources disagree?"
-->

---
layout: two-cols-code
heading: Where values come from — and who wins
---

```hcl
variable "environment" {
  type    = string
  default = "dev"        # 1. weakest
}

# 2. TF_VAR_environment=staging   (env)
# 3. terraform.tfvars             (auto-loaded)
# 4. *.auto.tfvars                (auto-loaded)
# 5. -var / -var-file             (CLI, strongest)
```

::right::

<div class="mt-2 text-sm">

The precedence stack, **lowest → highest** — each click adds the next winner:

</div>

<div class="mt-3 space-y-2 text-sm">
  <div class="flex items-center gap-2"><KwChip>1</KwChip><code>default</code> in the <code>variable</code> block</div>
  <div v-click class="flex items-center gap-2"><KwChip>2</KwChip><code>TF_VAR_*</code> environment variable</div>
  <div v-click class="flex items-center gap-2"><KwChip>3</KwChip><code>terraform.tfvars</code></div>
  <div v-click class="flex items-center gap-2"><KwChip variant="ok">4</KwChip><code>*.auto.tfvars</code></div>
  <div v-click class="flex items-center gap-2"><KwChip variant="warn">5</KwChip><strong><code>-var</code> / <code>-var-file</code></strong> — CLI wins</div>
</div>

<div v-click class="mt-4 kw-muted text-sm">

A later `-var` on the same line beats an earlier one. The lab proves this: a
`terraform.tfvars` value gets overridden by `-var` at apply.

</div>

<!--
Say: Precedence, built bottom-up with the clicks. Start at the floor: the default
in the variable block. A TF_VAR_ environment variable beats the default. A
terraform.tfvars file beats the env var. Any *.auto.tfvars beats that. And a -var
or -var-file on the command line beats everything — last -var on the line wins ties.
Stress the direction because it's easy to get backwards: default is weakest, CLI is
strongest. The lab makes it concrete — a tfvars value overridden by -var at apply.
(~4 min)
Then: "Two more constructs that matter for secrets and results — sensitive and
outputs."
-->

---

<span class="kw-kicker">Secrets & results</span>

# Sensitive values and outputs

<div class="kw-cols-2 mt-4">
  <KwCard heading="sensitive = true" kind="variable" variant="danger">
    <strong>Masked, not encrypted.</strong> A sensitive variable or output prints
    as <code>&lt;sensitive&gt;</code> in plan, apply, and <code>tofu output</code>.
    It still lands in <strong>state</strong> — that's S05's job.
  </KwCard>
  <KwCard heading="output {}" kind="output" variant="ok">
    <strong>Your config's return values.</strong> Export a computed result;
    a parent module or the CLI reads it. Unmask a sensitive one on purpose with
    <code>tofu output -raw NAME</code>.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

`sensitive` stops shoulder-surfing and log leaks — it is **not** encryption. The
value is still plaintext in state, which is exactly why the previous section
encrypts state.

</div>

<!--
Say: Two constructs for secrets and results. sensitive = true masks a value as
angle-bracket-sensitive everywhere it would print — plan, apply, tofu output — so
it doesn't leak into a shared terminal or CI log. Say the important caveat out
loud: masking is not encryption; the value is still plaintext in state, which is
exactly the problem the previous section's state encryption solves. Outputs are
your config's return values — export a computed result for a parent module or the
CLI, and unmask a sensitive one deliberately with tofu output -raw. (~3 min)
Then: "One point of pride for OpenTofu before we send you to the lab."
-->

---
layout: comparison
heading: Cross-variable validation — the OpenTofu 1.9 line
leftHeading: OpenTofu
rightHeading: Terraform
leftBadge: '1.9+'
rightBadge: '1.9+'
---

- Validation `condition` may reference **other variables**, `data`, and `local`s
- Still must reference the variable being validated
- Clear diagnostic naming **every** referenced value
- Part of OpenTofu's push to validate the whole config, not one field

::right::

- Also gained cross-object validation references in **1.9** (June 2024)
- Same requirement: reference the variable under validation
- Pre-1.9: a condition could read only its own variable
- Older engines error with *"Invalid reference in variable validation"*

<!--
Say: Set the record straight so nobody gets caught out in review. Cross-variable
validation — a condition reading other variables, data sources, and locals — landed
in OpenTofu 1.9, and it is genuinely powerful: you validate the whole config, not
one isolated field, and the diagnostic names every value it read. Be honest on the
right: Terraform added the same capability in its own 1.9, back in mid-2024, so
this isn't an OpenTofu exclusive — but it IS a modern-engine feature; anything
pre-1.9 could only read the variable under validation. Teach it as current best
practice, credited to OpenTofu 1.9. (~2 min)
Then: "Now go parameterize a real config and break a rule on purpose — Lab 06."
-->

---
layout: lab
lab: labs/day-1/06-variables.md
duration: 25 min
env: 'mock ✓ (no docker)'
---

# Lab 06 — parameterize with typed, validated variables

Refactor a hardcoded local config into a typed `object` variable, a `sensitive`
token, and outputs. **Break a cross-variable `validation` on purpose**, read the
real error, then fix it. Prove precedence by overriding a `terraform.tfvars` value
with `-var`, and watch a `sensitive` output print as `<sensitive>`.

Every task has a `<details>` spoiler; panic reset leaves the tree clean.

<!--
Say: Set up the lab and its two payoff moments. You'll parameterize a real local
config — typed object variable, sensitive token, outputs — then deliberately break
the cross-variable validation (a prod service with one replica) to see OpenTofu's
diagnostic name both variables it read, and fix it. The second payoff is
precedence: a terraform.tfvars value visibly overridden by -var at apply, and a
sensitive output masked as angle-bracket-sensitive. No Docker — pure local
providers. Every task has a spoiler; panic reset leaves the tree clean.
(~25 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Variables, validation & types — recap
story: 'Typed, validated inputs turn a config into a reusable, self-checking module.'
next: 'Next: Validation, pre/postconditions & check blocks'
---

- Variables are **typed inputs**; outputs are exported results — together, a module.
- Types: **primitive**, **collection**, **structural** (`object`) — prefer one
  typed `object` over loose variables.
- Precedence, low → high: `default` < `TF_VAR_*` < `terraform.tfvars` <
  `*.auto.tfvars` < `-var`.
- `validation` blocks fail fast; **cross-variable** conditions (OpenTofu 1.9) reason
  across the config.
- `sensitive` masks output — it is **not** encryption (that's S05's state story).

<!--
Say: Pull the threads together. Variables are typed inputs, outputs are exported
results, and the pair makes a reusable module. Three type families — primitive,
collection, structural — and the guidance to prefer one typed object. The
precedence stack, weakest to strongest: default, TF_VAR, terraform.tfvars,
auto.tfvars, then -var on the CLI. Validation blocks fail fast, and cross-variable
conditions from OpenTofu 1.9 let a rule reason across the whole config. And
sensitive masks, it doesn't encrypt. Call forward: the very next section goes deep
on validation — preconditions, postconditions, and check blocks — building right on
this foundation. (~2 min)
Then: transition into Validation, pre/postconditions & check blocks.
-->
