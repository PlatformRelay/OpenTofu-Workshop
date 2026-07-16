---
layout: section-cover
image: /covers/section-15-the-checkpoint-gates.png
day: Day 1
section: '15'
tier: core
---

# Validation, pre/postconditions & checks

`validation` guards inputs. But a real config also needs to guard a resource's
inputs, the values it exports, and the result after it is built — each at the
right phase. Meet OpenTofu's four native assertions.

<!--
Say: Frame the section as the natural next step after S06. There, a validation
block guarded a variable's value. But inputs aren't the only thing worth
guarding: you also want to assert on a resource's inputs before it plans, on the
result after it's built, and on values you export — and crucially, each of those
fires at a different phase of the run. This section is the map of the four native
assertions and exactly when each one evaluates. (~1 min)
Then: "Let's start with the one you already know, then add three more."
-->

---
layout: statement
kicker: 'From S06'
---

`validation` was the **first** assertion — but it only guards a **variable**.

Three more guard the rest of the config: a **`precondition`** (inputs), a
**`postcondition`** (results), and a non-blocking **`check`**.

<!--
Say: Land the through-line from the last section. The validation block you met in
S06 is assertion number one, but it's narrow: it only guards a variable's own
value. OpenTofu gives you three more that cover the rest of the config —
preconditions guard what goes into a resource, postconditions guard what comes
out, and check blocks are a non-blocking, advisory guard. The whole section hangs
off that four-way frame. (~2 min)
Then: "The thing that trips people up isn't what each does — it's WHEN each runs."
-->

---

<span class="kw-kicker">The four native assertions</span>

# Four guards, three phases

<div class="kw-cols-2 mt-4">
  <KwCard heading="validation {}" kind="validation">
    <strong>Guards a variable.</strong> In the <code>variable</code> block; fails
    at <strong>plan</strong>. Cross-variable since 1.9 (S06).
  </KwCard>
  <KwCard heading="precondition {}" kind="validation" variant="warn">
    <strong>Guards inputs.</strong> In a resource <code>lifecycle</code> or an
    <code>output</code>; fails at <strong>plan</strong>, before anything is built.
  </KwCard>
  <KwCard heading="postcondition {}" kind="validation" variant="danger">
    <strong>Guards results.</strong> In a resource <code>lifecycle</code>; reads
    the built value, so it fails at <strong>apply</strong>.
  </KwCard>
  <KwCard heading="check {}" kind="test" variant="ok">
    <strong>Non-blocking.</strong> A top-level block; <strong>warns</strong> at
    plan AND apply, never fails the run.
  </KwCard>
</div>

<div v-click class="mt-4 kw-muted text-sm">

Version floor: `precondition` / `postcondition` land in **1.2**; `check` blocks
in **1.5**. All GA in current OpenTofu.

</div>

<!--
Say: This is the reference grid for the whole section. Validation guards a
variable and fails at plan. A precondition guards a resource's inputs — it lives
in a lifecycle block or an output, and it fails at plan, before anything is built.
A postcondition guards the result — it reads the built value, so it can only be
checked at apply. And a check block is the outlier: non-blocking, it warns at both
plan and apply and never fails the run. The click adds the version floors —
pre/postconditions from 1.2, checks from 1.5, all GA today. Everything that
follows is just these four placed on the timeline. (~3 min)
Then: "Let's put them on the plan/apply timeline so the phases are unmistakable."
-->

---
layout: two-cols-code
heading: Each assertion on the plan → apply timeline
---

```hcl
# PLAN phase — evaluated before any change:
#   variable.validation      → guards a variable
#   lifecycle.precondition   → guards a resource's inputs
#   output.precondition      → guards an exported value

# APPLY phase — evaluated after the resource is built:
#   lifecycle.postcondition  → reads self.*, guards the result

# PLAN *and* APPLY — advisory, never blocks:
#   check {}                 → emits a Warning, run still succeeds
```

::right::

<div class="mt-2">
  <PlanApplyFlow :step="$clicks" />
</div>

<div v-click class="mt-3 text-sm kw-muted">

The rule of thumb: an assertion fires **as soon as the values it reads are
known**. A `postcondition` reading `self.content` can't resolve until apply — so
that's when it runs.

</div>

<!--
Say: This is the mental model that makes the rest stick — reuse the core
PlanApplyFlow visual and light it stage by stage. Preconditions and validation
sit in the plan phase: they read plan-known values, so they fail before anything
is built. The postcondition sits in apply: it reads self-dot-something — a value
that isn't known until the resource actually exists — so it can only run at apply.
And the check spans both phases as an advisory warning. State the rule of thumb
out loud, because it explains everything: an assertion fires as soon as the values
it reads become known. That single rule tells you the phase every time. (~4 min)
Then: "Let's grow a precondition and a check onto the S06 module and read the
exact diagnostics."
-->

---
layout: two-cols-code
heading: Layer a precondition and a check onto the S06 module
lab: labs/day-1/15-conditions-checks.md
---

````md magic-move
```hcl
# 1. The S06 shape: a file the service object drives. No guards yet.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = local.rendered
}
```

```hcl
# 2. A precondition guards the INPUTS — fails at PLAN.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = local.rendered

  lifecycle {
    precondition {
      condition     = var.service.replicas >= 1
      error_message = "A service needs at least 1 replica."
    }
  }
}
```

```hcl
# 3. A postcondition guards the RESULT — reads self.*, fails at APPLY.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = local.rendered

  lifecycle {
    precondition {
      condition     = var.service.replicas >= 1
      error_message = "A service needs at least 1 replica."
    }
    postcondition {
      condition     = length(self.content) <= var.max_manifest_bytes
      error_message = "Manifest exceeds ${var.max_manifest_bytes} bytes."
    }
  }
}
```

```hcl
# 4. A check is SEPARATE and non-blocking — warns, never fails the run.
check "secret_strength" {
  assert {
    condition     = var.min_secret_length >= 16
    error_message = "Session secret should be >= 16 chars."
  }
}
```
````

::right::

<div class="mt-2">
  <KwCard heading="precondition → plan" kind="validation" variant="warn">
    <strong>Reads inputs</strong> (<code>var.*</code>), so it resolves at plan.
    A false condition stops the plan — nothing is built.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="postcondition → apply" kind="validation" variant="danger">
    <strong>Reads <code>self.content</code></strong> — known only after the file
    is written — so it runs at apply, after creation.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="check {} → advisory" kind="test" variant="ok">
    A <strong>top-level</strong> block, not nested in a resource. Fails as a
    <strong>Warning</strong>; the run still completes.
  </KwCard>
  </div>
</div>

<!--
Say: This is the magic-move heart of the section, growing guards onto the exact
S06 file shape. Move one: the plain local_file the service object drives, no
guards. Move two: add a lifecycle precondition — it reads var-dot-something, so it
resolves at plan and stops a bad plan before anything is built. Move three: add a
postcondition that reads self-dot-content — the rendered file — which isn't known
until apply, so it runs at apply, after the file exists. Move four: the check is
deliberately a separate top-level block, not nested in the resource, and it fails
only as a warning. The HCL here is illustrative for reading; the lab's tracked
main.tf is the byte-exact source. (~6 min)
Then: "So when do you reach for which? Here's the decision."
-->

---

<span class="kw-kicker">When to use which</span>

# Blocking vs advisory — pick deliberately

<div class="kw-cols-2 mt-4">
  <KwCard heading="Block the run" kind="validation" variant="danger">
    <strong>precondition / postcondition.</strong> A broken invariant that must
    stop delivery — bad input, or a result that violates a contract. Fails hard.
  </KwCard>
  <KwCard heading="Warn, keep going" kind="test" variant="ok">
    <strong>check {}.</strong> A soft signal you want visible but not
    show-stopping — drift, a weak-but-tolerable value, a health probe. Advisory.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

A `check` can even embed its **own scoped `data` source** to poll live infra after
apply — a health check that reports without ever failing the run. Reach for a
`precondition` when a violation *must* stop you; a `check` when you only need to
*know*.

</div>

<!--
Say: Make the choice deliberate, because the phase isn't the only axis — blocking
versus advisory is. Preconditions and postconditions are for invariants that must
stop delivery: a bad input, or a built result that violates a contract. They fail
hard, on purpose. A check is for a soft signal you want surfaced but not
show-stopping — configuration drift, a value that's weak but tolerable, a
post-apply health probe. The click adds the check's signature power: it can embed
its own scoped data source to poll live infrastructure after apply and report
without ever failing the run. The test: does a violation have to stop you, or do
you just need to know? (~3 min)
Then: "Now go layer these onto the S06 module and break the postcondition on
purpose — Lab 15."
-->

---
layout: lab
lab: labs/day-1/15-conditions-checks.md
duration: 30 min
env: 'mock ✓ (no docker)'
---

# Lab 15 — preconditions, postconditions & check blocks

Carry the S06 `service` module forward and layer four assertions onto it. Trip the
**`check`** (a warning, run survives), block a **`precondition`** at plan, then
**break a `postcondition` on apply** — read the diagnostic line-by-line and fix it.

Every task has a `<details>` spoiler; panic reset leaves the tree clean.

<!--
Say: Set up the lab and its payoff. You'll carry the S06 service module forward and
add all four assertions, then exercise each one's phase. First trip the check and
watch it warn while the run survives — proof it's non-blocking. Then block a
precondition at plan, before anything is built. Then the headline break→fix:
squeeze the byte budget so the postcondition fails on apply, after the file is
already written — read that diagnostic top to bottom, then fix it. No Docker, pure
local providers. Every task has a spoiler; panic reset leaves the tree clean.
(~30 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Validation, pre/postconditions & checks — recap
story: 'Native assertions guard inputs, results, and exports — each at the right phase.'
next: 'Next: Modules — reuse, inputs & outputs'
---

- Four native guards: `validation` (variable), `precondition` (inputs),
  `postcondition` (results), `check` (advisory).
- **Phase follows the values read:** validation + preconditions fail at **plan**;
  a `postcondition` reads `self.*`, so it fails at **apply**.
- A **`check`** is **non-blocking** — it warns at plan *and* apply and never fails
  the run. Use it for soft signals and post-apply probes.
- Version floor: pre/postconditions **1.2**, `check` blocks **1.5** — all GA today.
- Read every diagnostic line by line: severity, `on main.tf line N`, the failing
  `condition`, the values, then your `error_message`.

<!--
Say: Pull the threads together. Four native guards — validation for a variable,
precondition for a resource's or output's inputs, postcondition for the built
result, and check as the advisory one. The single rule that fixes the phase in
your head: an assertion fires as soon as the values it reads are known, so
validation and preconditions fail at plan while a postcondition, reading
self-dot-something, fails at apply. Checks are non-blocking — they warn at both
phases and never stop the run, ideal for soft signals and health probes.
Version floors: pre/post from 1.2, checks from 1.5. And the reading skill: every
diagnostic is severity, site, condition, values, message — read it top to bottom.
Call forward: next we package this into reusable modules with their own inputs and
outputs. (~2 min)
Then: transition into Modules — reuse, inputs & outputs.
-->
