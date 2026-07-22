---
layout: section-cover
image: /covers/section-12-the-safety-briefing.png
day: Day 2
section: '12'
tier: core
---

# Why test IaC + the testing pyramid

<!--
Say: Day 2 changes the question from “can we author infrastructure?” to “what evidence lets us trust a change?” Testing IaC is layered because no single check catches syntax, contract, API, and production failures at the same cost. (~2 min)
Then: “Start with the failure modes that make infrastructure different from ordinary application code.”
-->

---

<span class="kw-kicker">Why infrastructure needs evidence</span>

# A valid plan can still be wrong

<div class="kw-cols-2 mt-5">
  <KwCard heading="Cheap defects" icon="⚡">
    Formatting drift, invalid references, unsafe defaults, and broken contracts
    can be caught without creating anything.
  </KwCard>
  <KwCard heading="Reality defects" icon="🌍">
    Permissions, API behaviour, eventual consistency, quotas, and teardown only
    appear when a provider talks to a service.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">
The goal is not “more tests.” It is the **cheapest trustworthy signal** for each risk.
</div>

<!--
Say: Separate defects by where they can be observed. Many mistakes are knowable from configuration or a plan; others exist only at an API boundary. Land the reveal: optimize for the cheapest signal that can actually disprove the risk. (~3 min)
Then: “That cost gradient gives us the testing pyramid.”
-->

---
clicks: 4
---

<span class="kw-kicker">Build evidence bottom-up</span>

# The IaC testing pyramid

<TestPyramid
  :step="$clicks"
  :static-tools="['fmt', 'validate', 'lint', 'policy']"
  :unit-tools="['tofu test (plan)', 'mock_provider']"
  :integration-tools="['LocalStack', 'sandbox APIs']"
  :e2e-tools="['real environment']"
/>

<div class="mt-2 text-center kw-muted text-sm">
Fast and many at the base → slow and few at the tip
</div>

<!--
Say: Reveal from the base upward. Static checks inspect configuration; unit/contract tests evaluate plans with controlled inputs; integration crosses a service boundary; end-to-end proves a real environment. The pyramid is a portfolio rule: many cheap checks, progressively fewer expensive ones. (~4 min)
Then: “The layer is determined by the boundary crossed, not the tool’s brand name.”
-->

---

<span class="kw-kicker">Classify by boundary</span>

# Ask: what must be real?

| Check | Boundary | Layer |
| --- | --- | --- |
| `tofu fmt -check` | text | static |
| `tofu test` + `mock_provider` | plan/contract | unit |
| apply an S3 bucket to LocalStack | service API | integration |
| deploy and probe a production-like stack | full system | e2e |

<div v-click class="mt-5 kw-panel p-4 text-sm">
<strong>Deliberately debatable:</strong> <code>tofu validate</code> is usually static
because it creates nothing, but provider schema loading gives it a contract flavour.
Name the boundary and the classification becomes useful.
</div>

<!--
Say: Classify by the boundary required to obtain the signal. A tool can participate in more than one layer depending on command mode. Use validate as the honest ambiguous case: call it static in this workshop, while acknowledging its provider-schema contract flavour. (~4 min)
Then: “Every step upward buys fidelity and pays in time, flakiness, and cleanup.”
-->

---
layout: comparison
---

::left::

## Lower layers

- seconds, deterministic
- run on every edit or commit
- precise failure messages
- cannot prove service behaviour

::right::

## Higher layers

- realistic APIs and lifecycle
- expose permissions and timing
- slower, costlier, more stateful
- require isolation and cleanup

<!--
Say: Make the trade explicit. Lower layers provide fast diagnosis but cannot prove a remote service; higher layers provide fidelity but introduce time, state, and operational failure modes. A healthy suite escalates only when the risk demands it. (~3 min)
Then: “The pyramid is guidance, not a law about the exact silhouette of every team’s suite.”
-->

---
layout: statement
kicker: 'Pyramid, diamond, or something else?'
---

**Keep the principle; adapt the shape.**

Some teams describe a testing “diamond” when integration tests carry unusual
value. That is commentary, not a second canon here: keep feedback fast, make
boundaries explicit, and reserve real environments for risks only they expose.

<!--
Say: Avoid turning the diagram into doctrine. A diamond can be a useful description when service integration dominates risk, but the durable principle is economic: fast feedback first, explicit boundaries, scarce end-to-end runs. (~2 min)
Then: “Now classify a real set of checks and run one contract test yourself.”
-->

---
layout: lab
lab: labs/day-2/12-testing-pyramid.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 12 — classify the evidence

Sort checks by boundary, run a plan-only contract test, deliberately break its
assertion, then restore the fast green signal.

<!--
Say: Learners first classify checks, including the intentionally ambiguous validate case. Then they run a real plan-only tofu test, break its expected contract through an input, read the assertion failure, and restore it. No Docker or cloud service is involved. (~20 min)
Then: “Debrief by naming which higher layer would catch what this contract test cannot.”
-->

---
layout: recap
next: 'S13 · Static analysis & formatting'
---

# Evidence before infrastructure

- Choose the cheapest signal that can expose the risk.
- Build **static → unit → integration → e2e** from many fast checks to few slow ones.
- Classify by the boundary crossed, not by the tool name.
- Higher fidelity always brings more state, time, and cleanup.

<!--
Say: Recap the decision rule rather than memorizing tool lists. The pyramid organizes evidence by cost and boundary; it does not require every project to have identical proportions. (~2 min)
Then: “We begin at the base with formatting, validation, and static analysis.”
-->
