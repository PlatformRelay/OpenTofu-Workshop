---
layout: section-cover
image: /covers/section-11-the-contractors-fair.png
day: Day 1
section: '11'
tier: optional
---

# The TACO landscape

You can author, guard, and package OpenTofu. But who runs it — with remote state,
RBAC, policy, and audited pipelines — once a team outgrows a laptop? Meet the
**TACO** layer: the orchestration platforms that wrap the CLI.

<!--
Say: Frame this optional section as the "day 2 of operations" question. Everything
so far has been about the tofu CLI on your own machine. The moment more than one
person runs it against shared state, you need something around the CLI: locked
remote state, who-can-run-what, policy gates, and an audit trail. That layer has a
name in the ecosystem — TACO, Terraform Automation and Collaboration Offerings —
and this section maps the landscape so you can choose one for an OpenTofu shop. It
is deliberately vendor-neutral: we compare public products on defensible axes and
do not crown a winner. (~1 min)
Then: "Start with what any platform in this layer is actually for."
-->

---
layout: statement
kicker: 'The layer'
---

**TACO** = *Terraform Automation & Collaboration Offerings* — the orchestration
platform that runs your IaC.

The CLI plans and applies. A TACO platform decides **who** may run it, against
**what state**, under **which policy**, and leaves an **audit trail**.

<!--
Say: Define the term plainly. TACO stands for Terraform Automation and
Collaboration Offerings — it is the ecosystem label for the orchestration layer
that sits on top of the CLI, and it applies just as much to OpenTofu as to
Terraform. The distinction to land: the CLI is the engine that plans and applies,
but a TACO platform is everything around it — access control, shared state,
policy, and audit. You reach for one when a single laptop and a shared state file
stop being safe. (~2 min)
Then: "Concretely, what does that platform give you? Six capabilities."
-->

---

<span class="kw-kicker">What the layer provides</span>

# Six capabilities a TACO platform adds

<div class="kw-cols-3 mt-4">
  <KwCard heading="Remote state + locking" kind="state" variant="accent">
    <strong>Shared, locked backend.</strong> One source of truth; concurrent runs
    serialize instead of corrupting state.
  </KwCard>
  <KwCard heading="RBAC" kind="validation" variant="warn">
    <strong>Who may run what.</strong> Roles, teams, and workspace scoping — plan
    vs apply, prod vs dev, gated by identity.
  </KwCard>
  <KwCard heading="Policy-as-code" kind="test" variant="danger">
    <strong>Guardrails on every run.</strong> A policy engine (OPA/Rego, Sentinel,
    or built-in) blocks a plan that violates the rules.
  </KwCard>
  <KwCard heading="Run pipelines / VCS-driven" kind="module" variant="ok">
    <strong>Runs from a PR.</strong> A merge or PR triggers plan then apply, with
    the plan posted back for review.
  </KwCard>
  <KwCard heading="Drift detection" kind="state">
    <strong>State vs reality.</strong> Scheduled plans surface out-of-band changes
    before they bite.
  </KwCard>
  <KwCard heading="Cost visibility" kind="output" variant="ok">
    <strong>Spend before apply.</strong> Estimate the cost delta of a plan so a
    reviewer sees the bill, not just the diff.
  </KwCard>
</div>

<div v-click class="mt-4 kw-muted text-sm">

Not every platform ships all six, and depth varies. The next slide compares them
on the axes that actually **steer a choice** — starting with the one that is
binary for an OpenTofu shop.

</div>

<!--
Say: This is the capability checklist — the vocabulary for reading any platform's
marketing page. Remote state with locking gives you one shared, serialized source
of truth instead of a state file emailed around. RBAC decides who may plan versus
apply, in prod versus dev. Policy-as-code puts a guardrail on every run — an OPA
or Sentinel or built-in engine that can fail a non-compliant plan. VCS-driven runs
turn a pull request into a plan-and-apply pipeline with the plan posted back for
review. Drift detection runs scheduled plans to catch out-of-band changes. And
cost visibility estimates the spend delta so a reviewer sees the bill. The click is
the honest caveat: platforms differ in which of these they ship and how deep each
goes — so let us compare. (~4 min)
Then: "Here is the landscape on five decision axes — revealed one row at a time."
-->

---

<span class="kw-kicker">The landscape</span>

# Comparing the field — one axis at a time

<div class="kw-stamp">
Landscape verified 2026-07 — this is the fastest-rotting slide; re-verify vendor
facts before delivery.
</div>

<table class="kw-taco-table mt-3">
  <thead>
    <tr>
      <th>Platform</th>
      <th>OpenTofu support</th>
      <th>Self-host option</th>
      <th>Policy engine</th>
      <th>Cost visibility</th>
      <th>OSS / proprietary</th>
    </tr>
  </thead>
  <tbody>
    <tr v-click>
      <td><strong>HCP Terraform</strong></td>
      <td class="cell-no">✗ Terraform only</td>
      <td>SaaS (self-host = TF Enterprise)</td>
      <td>Sentinel + OPA</td>
      <td>✓</td>
      <td>Proprietary</td>
    </tr>
    <tr v-click>
      <td><strong>Spacelift</strong></td>
      <td class="cell-yes">✓</td>
      <td>✓ self-host / air-gap</td>
      <td>OPA (Rego)</td>
      <td>✓</td>
      <td>Proprietary</td>
    </tr>
    <tr v-click>
      <td><strong>env0</strong></td>
      <td class="cell-yes">✓</td>
      <td>SaaS + self-hosted agents</td>
      <td>OPA (Rego)</td>
      <td>✓</td>
      <td>Proprietary</td>
    </tr>
    <tr v-click>
      <td><strong>Scalr</strong></td>
      <td class="cell-yes">✓</td>
      <td>SaaS + self-hosted agents</td>
      <td>OPA (Rego)</td>
      <td>✓</td>
      <td>Proprietary</td>
    </tr>
    <tr v-click>
      <td><strong>Atlantis</strong></td>
      <td class="cell-yes">✓</td>
      <td>✓ self-host (you run it)</td>
      <td>Bring-your-own (OPA/conftest)</td>
      <td>Add-on</td>
      <td class="cell-yes">OSS</td>
    </tr>
  </tbody>
</table>

<div v-click class="mt-3 kw-muted text-sm">

Cells are kept **coarse on purpose** — a ✓ means "supported", not a feature audit.
The one hard, binary fact is the top-left cell; the next slide unpacks it.

</div>

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
  letter-spacing: 0.01em;
}
.kw-taco-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8rem;
}
.kw-taco-table th,
.kw-taco-table td {
  border: 1px solid var(--kw-border);
  padding: 0.4rem 0.6rem;
  text-align: left;
}
.kw-taco-table thead th {
  background: var(--kw-panel-2);
  color: var(--kw-text);
  font-weight: 600;
}
.kw-taco-table td.cell-yes { color: var(--kw-ok); font-weight: 600; }
.kw-taco-table td.cell-no { color: var(--kw-danger); font-weight: 600; }
</style>

<!--
Say: Reveal this one row at a time so the room reads each platform before the next
appears. Read the stamp aloud first — this is the fastest-rotting slide in the deck,
so re-verify every vendor fact before you deliver it. Row one, HCP Terraform: the
standout is the red cell — it runs Terraform only, no native OpenTofu. Rows two
through four — Spacelift, env0, Scalr — all support OpenTofu; they differ mainly on
how you self-host and on packaging. Row five, Atlantis, is the open-source outlier:
you run it yourself and bring your own policy engine. Keep every cell coarse — a
checkmark means "supported", not a feature-by-feature audit, because those details
rot fastest. Do not editorialize a winner; the axes steer the choice, not us.
(~4 min)
Then: "That top-left cell is the one fact that steers an OpenTofu shop — unpack it."
-->

---
layout: statement
kicker: 'The one hard fact'
---

**HCP Terraform runs Terraform only.** OpenTofu is not supported on it.

An OpenTofu config can push state via the `remote` backend, but native runs,
Sentinel policy, and the private registry are **Terraform-only** — a real
constraint that removes HCP Terraform from an OpenTofu shop's shortlist.

<!--
Say: This is the single most decision-relevant fact in the section, and it is
binary, so state it flatly. HCP Terraform — HashiCorp's managed platform — runs
Terraform only; OpenTofu is not a supported engine on it. You can still point an
OpenTofu config at it as a remote state backend, but the platform's actual value —
native remote runs, Sentinel policy, the private module registry — is Terraform
only. For a shop that has committed to OpenTofu, that is not a preference, it is a
hard filter: HCP Terraform simply leaves the shortlist. This is not a knock on the
product; it is the fact that steers the choice. (~2 min)
Then: "So how should you actually choose from what remains?"
-->

---

<span class="kw-kicker">How to choose</span>

# Choosing: constraints first, features second

<div class="kw-cols-2 mt-4">
  <KwCard heading="1. Hard filters" kind="validation" variant="danger">
    <strong>Non-negotiables that eliminate options.</strong> "Must run OpenTofu"
    drops HCP Terraform. "Must self-host / air-gap" drops SaaS-only tiers.
  </KwCard>
  <KwCard heading="2. Policy model" kind="test" variant="warn">
    <strong>Which engine, and who writes it.</strong> OPA/Rego is portable and
    open; a proprietary engine locks policy to the platform.
  </KwCard>
  <KwCard heading="3. Operating cost" kind="output" variant="ok">
    <strong>Run it, or pay for it.</strong> OSS/self-host trades a licence bill for
    the ops burden of running the platform yourself.
  </KwCard>
  <KwCard heading="4. Team scale" kind="module" variant="accent">
    <strong>Fit to size.</strong> A small team may want managed SaaS; a large,
    regulated org may need self-host, RBAC depth, and audit.
  </KwCard>
</div>

<div v-click class="mt-4 kw-muted text-sm">

**Order matters:** apply the hard filters first — they shrink the field to a
shortlist — *then* weigh the soft trade-offs. The lab makes you do exactly that on
a scenario.

</div>

<!--
Say: Give them a repeatable method, not a favourite. Step one is hard filters —
the non-negotiables that eliminate options outright: "must run OpenTofu" removes
HCP Terraform, "must self-host or air-gap" removes any SaaS-only tier. Apply those
first because they shrink the field fastest. Step two, the policy model: an
open engine like OPA-slash-Rego is portable across platforms, while a proprietary
engine ties your policy to one vendor. Step three, operating cost: open-source and
self-host trade a licence bill for the burden of running the platform yourself.
Step four, team scale: a small team often wants managed SaaS, a large regulated org
needs self-host, deep RBAC, and audit. The click is the discipline — filters first,
trade-offs second. That is exactly the shape of the lab. (~3 min)
Then: "Now apply this to a real scenario — the paper lab."
-->

---
layout: lab
lab: labs/day-1/11-taco-landscape.md
duration: 20 min
env: 'paper ✓ (no cloud, no docker, no tofu)'
---

# Lab 11 — pick a platform, defend the choice

A **paper** decision exercise: given a set of hard constraints — *must run
OpenTofu, must self-host, needs policy-as-code, small team* — you shortlist and
pick a TACO platform, then justify it against a scoring **rubric**.

No cloud, no Docker, no `tofu` run. Every scenario ships a `<details>` rationale.

<!--
Say: Set up the paper lab and its payoff. There is nothing to apply here — it is a
decision exercise on purpose, because platform choice is a judgement, not a
command. You are handed a set of hard constraints: must run OpenTofu, must
self-host, needs policy-as-code, small team. You apply the filters-first method
from the previous slide, shortlist the field, pick one platform, and defend it
against a scoring rubric. Then you check your reasoning against the spoiler
rationale. It is a twenty-minute discussion — no cloud, no Docker, no tofu.
(~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: The TACO landscape — recap
story: 'The orchestration layer around the CLI — choose it constraints-first, and mind the OpenTofu filter.'
next: 'Next: The testing pyramid'
---

- **TACO** is the orchestration layer above the CLI: remote state + locking, RBAC,
  policy-as-code, VCS-driven runs, drift detection, and cost visibility.
- No platform ships all six equally — compare on axes that **steer a choice**:
  OpenTofu support, self-host, policy engine, cost visibility, OSS vs proprietary.
- **HCP Terraform runs Terraform only** — OpenTofu is not supported, so it drops
  off an OpenTofu shop's shortlist regardless of other merits.
- Platforms with first-class OpenTofu support include **Spacelift, env0, Scalr**
  (proprietary) and **Atlantis** (OSS, self-run).
- **Choose constraints-first:** hard filters eliminate, *then* weigh policy model,
  operating cost, and team scale. The slide is dated — re-verify vendor facts.

<!--
Say: Pull the threads together. TACO is the orchestration layer above the CLI, and
its job is six things: remote state with locking, RBAC, policy-as-code, VCS-driven
runs, drift detection, and cost visibility. No single platform ships all six at the
same depth, so you compare on the axes that actually steer a choice. The one hard,
binary fact: HCP Terraform runs Terraform only, so an OpenTofu shop filters it out
regardless of how good it otherwise is. Platforms with first-class OpenTofu support
include Spacelift, env0, and Scalr on the proprietary side, and Atlantis as the
open-source self-run option. And the method: apply hard filters first to shrink the
field, then weigh the soft trade-offs. Remind them the comparison is dated and rots
fast — re-verify before delivery. Call forward: next we shift from who runs your
IaC to how you test it — the testing pyramid. (~2 min)
Then: transition into The testing pyramid.
-->
