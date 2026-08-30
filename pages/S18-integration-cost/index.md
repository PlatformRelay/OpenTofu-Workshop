---
layout: section-cover
image: /covers/section-18-the-full-field-trial.webp
day: Day 2
section: '18'
tier: optional
---

# Integration, e2e & cost

<!--
Say: This optional climb puts Go-based end-to-end proof and cost estimation on the pyramid tip. Native tofu test already covers most contracts — Terratest and Infracost earn their keep only for risks those cheaper lanes cannot see. (~1 min)
Then: “Re-open the pyramid and put Terratest at the apex.”
-->

---
clicks: 4
---

<span class="kw-kicker">Same pyramid, tip lit</span>

# Terratest sits at the apex

<TestPyramid
  :step="$clicks"
  :static-tools="['fmt', 'validate', 'lint', 'policy']"
  :unit-tools="['tofu test (plan)', 'mock_provider']"
  :integration-tools="['LocalStack', 'tofu test (apply)']"
  :e2e-tools="['Terratest', 'real environment']"
/>

<div class="mt-2 text-center kw-muted text-sm">
Many cheap checks below → few expensive Go e2e runs at the tip
</div>

<!--
Say: Reuse TestPyramid from S12. Static and mocked plan tests stay at the base. LocalStack-backed native apply tests already cover most integration risk. Terratest is the tip: a real apply, assertions outside HCL, then destroy — slower, stateful, and worth it only when the claim needs that fidelity. (~3 min)
Then: “Name the moment Go e2e beats a native test.”
-->

---

<span class="kw-kicker">When Go earns its keep</span>

# Prefer `tofu test` until the claim escapes HCL

| Prefer native `tofu test` | Reach for Terratest |
| --- | --- |
| Plan/apply contracts on outputs and resources | Multi-step flows across CLIs or languages |
| Assertions expressible in HCL | HTTP / kubectl / SDK checks after apply |
| One OpenTofu root, one runner | Orchestration the native runner cannot express |
| Fast PR signal | Sparse, high-fidelity gates |

<div class="mt-4 kw-panel p-3 text-sm">
Terratest (Gruntwork) is a Go library: <strong>apply → assert → destroy</strong>.
This workshop runs it in a <strong>pinned container</strong> — no host Go required
(ADR 0011).
</div>

<!--
Say: Native tests already apply to LocalStack in S16. Go e2e pays off when you must assert through another client, chain tools, or keep teardown logic the team already owns in Go. Otherwise stay on tofu test — fewer languages, faster feedback. (~3 min)
Then: “Walk the minimal Terratest shape.”
-->

---
layout: two-cols-code
---

<span class="kw-kicker">Minimal Terratest shape</span>

# Apply, assert, defer destroy

```go
opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
  TerraformBinary: "tofu",
  TerraformDir:    ".",
  Vars: map[string]interface{}{
    "aws_endpoint": endpoint, // host or Compose DNS
  },
})

defer terraform.Destroy(t, opts)
terraform.InitAndApply(t, opts)

bucket := terraform.Output(t, opts, "bucket_name")
require.Equal(t, "s3-crmapp-d-web-tt", bucket)
```

::right::

<KwCard heading="Binary" kind="test" variant="ok">
<code>TerraformBinary: "tofu"</code> — OpenTofu-first, not a parallel Terraform track.
</KwCard>
<div class="mt-3">
<KwCard heading="Lifecycle" kind="resource">
<code>defer Destroy</code> runs even when an assertion fails.
</KwCard>
</div>
<div class="mt-3">
<KwCard heading="Lane" kind="validation" variant="warn">
<code>task lab:terratest DIR=…</code> — pinned Go + tofu container vs LocalStack.
</KwCard>
</div>

<!--
Say: The durable shape is three lines of intent: configure OpenTofu as the binary, defer destroy so failed asserts still clean up, then apply and read an output. The endpoint variable lets the same test hit localhost on a host Go lane or the Compose DNS name inside the container. (~4 min)
Then: “Cost estimation is a different tip — and deliberately optional.”
-->

---

<span class="kw-kicker">Cost without a cloud bill</span>

# Infracost estimates; it does not apply

```text
HCL ──infracost breakdown──▶ monthly cost table ──▶ PR diff comment
```

- Parses configuration (and optionally a plan JSON) — **no** `tofu apply`.
- Surfaces the price of an instance type change before merge.
- Needs a **free API key** for live runs — so this workshop keeps it an
  **optional stretch**, never a core step (ADR 0011).

<div class="mt-4 kw-panel p-3 text-sm">
No-signup promise: skip the stretch and the Terratest core lab still fully succeeds.
</div>

<!--
Say: Infracost answers “what will this change cost?” without creating infrastructure. Because the CLI needs a free API key, the core lab never requires signup — slides carry a captured demo, and the stretch is clearly labelled. (~3 min)
Then: “Show what a breakdown looks like so learners recognise it in a PR.”
-->

---
layout: code-walkthrough
---

<span class="kw-kicker">Demo output · optional stretch</span>

# Captured `infracost breakdown` (no live key needed here)

```text
Project: labs/day-2/18-terratest-cost/cost

 Name                                                 Monthly Qty  Unit   Monthly Cost

 aws_instance.web
 ├─ Instance usage (Linux/UNIX, on-demand, t3.micro)          730  hours        $7.59
 └─ root_block_device
    └─ Storage (general purpose SSD, gp3)                       8  GB           $0.64

 OVERALL TOTAL                                                                  $8.23
──────────────────────────────────
```

::notes::

<CodeNote at="1" label="Fixture">Priced HCL under <code>cost/</code> — never applied by Terratest.</CodeNote>
<CodeNote at="2" label="Signal">A t3.micro + 8 GiB gp3 root volume at list prices.</CodeNote>
<CodeNote at="3" label="PR use">Diff the same report against the base branch in CI.</CodeNote>

<!--
Say: This is a facilitator-captured demo of the cost fixture, not something learners must regenerate for the core lab. Point at the instance line and the overall total — that is the signal a PR comment would highlight when someone ups the instance size. (~2 min)
Then: “Run the provided Terratest; treat Infracost as an opt-in stretch.”
-->

---
layout: lab
lab: labs/day-2/18-terratest-cost.md
duration: 30 min
env: 'localstack ✓ · mock ✓'
---

# Lab — Terratest vs LocalStack (+ optional cost)

- Run the provided Terratest via `task lab:terratest` — **no host Go**.
- Watch apply → assert → destroy against pinned LocalStack.
- Break the Go assertion, read the failure, restore green.
- **Optional stretch:** Infracost breakdown — **requires a free API key**.

<!--
Say: Learners drive the container lane against LocalStack, prove cleanup, break and fix the assertion, then optionally price the cost fixture if they already have an Infracost key. Core success never depends on signup. (~30 min)
Then: “Debrief by naming which risks still belong below the tip.”
-->

---
layout: recap
next: 'S19 · Testing in CI/CD'
---

# Tip tools, scarce runs

- Terratest is Go e2e at the pyramid apex — use sparingly after native tests.
- Prefer `tofu test` until assertions escape HCL or need multi-tool orchestration.
- Container lane: `task lab:terratest DIR=…` — no host Go required.
- Infracost is cost/PR signal — optional stretch; core lab needs no API key.

<!--
Say: Close on economics: keep the tip thin. Native and LocalStack lanes catch most defects; Terratest and Infracost answer the residual questions that justify their cost. (~2 min)
Then: “Next: wire the whole pyramid into CI/CD.”
-->
