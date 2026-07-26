---
layout: section-cover
image: /covers/section-17-the-stand-in-props.png
day: Day 2
section: '17'
tier: core
---

# Mocking providers

<!--
Say: S16 proved native tests can plan and apply. This section removes the service boundary entirely: mock_provider and overrides let a plan-only suite run with zero credentials and no Docker. (~1 min)
Then: “Place mocking on the testing pyramid first.”
-->

---
clicks: 4
---

<span class="kw-kicker">Same pyramid, cheaper unit lane</span>

# Mocking lives in the unit / contract layer

<TestPyramid
  :step="$clicks"
  :static-tools="['fmt', 'validate', 'lint', 'policy']"
  :unit-tools="['tofu test (plan)', 'mock_provider']"
  :integration-tools="['LocalStack', 'sandbox APIs']"
  :e2e-tools="['real environment']"
/>

<div class="mt-2 text-center kw-muted text-sm">
Mocking buys speed and isolation — it does not prove a real API.
</div>

<!--
Say: Reuse the pyramid from S12. Static checks stay at the base. Mocked plan tests sit with other unit/contract evidence: they evaluate configuration without crossing a service API. LocalStack and real environments remain higher fidelity when the risk demands them. (~3 min)
Then: “OpenTofu 1.8 made the mock itself a first-class test construct.”
-->

---

<span class="kw-kicker">OpenTofu 1.8</span>

# Stand-ins arrived with the test runner’s next leap

| Construct | Role |
| --- | --- |
| `mock_provider` | Replace a provider so resources/data never hit a real API |
| `mock_resource` / `mock_data` | Supply `defaults` for computed attributes the plan would otherwise leave unknown |
| `override_resource` / `_data` / `_module` | Pin values for one address (file-wide or per `run`) |

<div class="mt-4 kw-panel p-3 text-sm">
Terraform shipped comparable override/mocking earlier (1.7). Teach the OpenTofu
blocks; the workshop’s floor remains OpenTofu <strong>1.8+</strong>.
</div>

<!--
Say: mock_provider swaps the whole provider. Nested mock_resource and mock_data fill known defaults for attributes a plan cannot invent. override_* targets a single address when one scenario needs different values — and a run-level override wins over file-level defaults. (~3 min)
Then: “Watch a plan test grow from empty run to fully mocked contract.”
-->

---
layout: two-cols-code
clicks: 5
---

<span class="kw-kicker">Mock swap · click by click</span>

# From apply appetite to mocked plan

<MockProviderFlow :step="$clicks" class="mt-6" />

<div v-click="5" class="mt-6 kw-muted text-sm">

Each click lights the next swap: an **apply run** on a real provider, a
**mock_provider** stand-in, a **plan-only** run, **mock_resource defaults** for
computed ids, then a **run-level override** so assertions read concrete values.

</div>

::right::

<KwCard heading="1 · Apply tax" kind="test" variant="warn">
An apply run wants a reachable API — LocalStack or cloud credentials.
</KwCard>
<div class="mt-3">
<KwCard heading="2 · Swap the provider" kind="provider" variant="ok">
<code>mock_provider</code> + <code>command = plan</code> — no Docker, no keys.
</KwCard>
</div>
<div class="mt-3">
<KwCard heading="3 · Pin known values" kind="validation">
<code>defaults</code> and <code>override_resource</code> make computed ids assertable.
</KwCard>
</div>

<!--
Say: Start from the apply-shaped appetite learners saw in S16. Click through MockProviderFlow: apply run on a real provider, swap in mock_provider, drop to command = plan, add mock_resource defaults for computed ids, then pin values with a run-level override_resource so assertions read concrete ARNs. (~4 min)
Then: “Choose mocking when the claim does not need a real service.”
-->

---
layout: comparison
---

::left::

## Prefer mocking when…

- the claim is about configuration / planned values
- credentials or Docker are unavailable (CI unit lane)
- you need fast, deterministic feedback on every edit
- LocalStack would only prove “something answered,” not the risk

::right::

## Prefer a real apply when…

- the claim needs API behaviour or lifecycle
- permissions, quotas, or eventual consistency matter
- teardown / destroy paths are the risk under test
- a mock would invent values the service never returns

<!--
Say: Mocking is not a moral upgrade over LocalStack — it is a cheaper boundary. Prefer it for contracts knowable from a plan. Escalate to an emulated or real API only when the defect cannot appear without one. (~3 min)
Then: “Put the conversion into a lab that keeps LocalStack firmly off.”
-->

---
layout: lab
lab: labs/day-2/17-mocking.md
duration: 30 min
env: 'mock ✓ (no docker)'
---

# Lab — mock the apply test, prove Docker is idle

- Convert an apply-style S3 contract into a mocked plan test.
- Run it with **zero credentials** while LocalStack is **down**.
- Break a wrong `override_resource` default, read the failure, restore green.

<!--
Say: Learners inspect the apply-shaped appetite, run the tracked mocked suite without Docker or cloud keys, deliberately poison the run-level override, then restore the file and clean provider caches. The edge criterion is explicit: LocalStack stays down for the whole green path. (~30 min)
Then: “Debrief by naming what this unit lane still cannot prove.”
-->

---
layout: recap
next: 'S18 · Integration, e2e & cost (optional)'
---

# Mocks buy isolation; APIs buy fidelity

- `mock_provider` (+ `mock_resource` / `mock_data` defaults) replaces a real API.
- `override_resource` / `_data` / `_module` pin one address; run-level wins.
- Prefer `command = plan` with mocks until the claim needs a service.
- A green mock never proves permissions, quotas, or real teardown.

<!--
Say: Recap the decision rule: mock for configuration contracts, escalate when the risk lives at the API. OpenTofu 1.8 made that swap native. (~2 min)
Then: “Next optional section climbs the pyramid with Terratest and cost estimation.”
-->
