---
layout: section-cover
image: /covers/section-01-the-two-blueprints.png
day: Day 1
section: '01'
tier: core
---

# Infrastructure as Code

Stop clicking consoles and running one-off scripts. Describe the infrastructure
you *want*, and let a tool make reality match — repeatably, reviewably, and with
a plan you can read before anything changes.

<!--
Say: Frame the whole day. IaC means you stop clicking consoles and running
throwaway scripts, and instead describe the infrastructure you WANT as code — then
a tool converges reality to that description, repeatably and reviewably. The hook
for this section: by the end you can explain WHY IaC beats scripts, and you'll know
the OpenTofu fork story that decides which CLI we teach. (~1 min)
Then: "Let's start with why — what's actually wrong with the old way."
-->

---

<span class="kw-kicker">Why IaC</span>

# The problem with doing it by hand

<div class="kw-cols-3 mt-4">
  <KwCard heading="Not repeatable" variant="danger">
    <strong>Snowflakes.</strong> Click-ops and one-off scripts drift apart. No two
    environments are ever quite the same.
  </KwCard>
  <KwCard heading="No preview" variant="warn">
    <strong>Blind changes.</strong> A script just runs. You find out what it did
    <em>after</em> it did it — sometimes in production.
  </KwCard>
  <KwCard heading="No memory" variant="warn">
    <strong>No drift detection.</strong> Nothing records what <em>should</em> exist,
    so nothing notices when reality wanders off.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

IaC answers all three: infrastructure becomes **code** — version-controlled,
reviewed in a PR, and reconciled to a desired state on every run.

</div>

<!--
Say: Three failure modes of doing infra by hand. Not repeatable — click-ops and
ad-hoc scripts produce snowflakes; no two environments match. No preview — a script
just runs, so you learn what it did after the fact, sometimes in prod. No memory —
nothing records desired state, so nothing detects drift. Then the click reveal: IaC
fixes all three by making infrastructure code — versioned, PR-reviewed, and
reconciled to a desired state every run. (~3 min)
Then: "This didn't appear overnight — here's the evolution that got us here."
-->

---

<span class="kw-kicker">How we got here</span>

# Click-ops → scripts → declarative IaC

<div class="kw-cols-3 mt-6">
  <KwCard heading="1 · Click-ops" variant="danger">
    Point-and-click in a console. Fast to start, impossible to reproduce, review,
    or audit. Every change is a manual snowflake.
  </KwCard>
  <div v-click>
  <KwCard heading="2 · Scripts" variant="warn">
    Imperative <code>bash</code>/SDK calls: the exact <em>steps</em> to take. Repeatable-ish,
    but not idempotent — re-running can double-create or fail halfway.
  </KwCard>
  </div>
  <div v-click>
  <KwCard heading="3 · Declarative IaC" variant="ok">
    Describe the <em>desired state</em>; the tool computes the diff and converges.
    Idempotent, previewable, drift-aware. Where we live now.
  </KwCard>
  </div>
</div>

<!--
Say: The evolution in three steps, revealed click by click. Click-ops: point and
click, fast to start but impossible to reproduce, review, or audit. Scripts: an
improvement — imperative bash or SDK calls capture the STEPS, so it's repeatable-ish,
but it's not idempotent, so re-running can double-create or die halfway. Declarative
IaC: you describe the desired STATE, the tool computes the diff and converges —
idempotent, previewable, drift-aware. Stress that each step fixed a real pain of the
one before it. (~3 min)
Then: "Let's pin down that word — declarative vs imperative — with real code."
-->

---
layout: statement
kicker: 'The core distinction'
---

**Imperative** says *how*: the steps to take.

**Declarative** says *what*: the state to reach.

The tool figures out the how — and can preview it, repeat it, and repair it.

<!--
Say: This is the one distinction to nail. Imperative code says HOW — the ordered
steps. Declarative code says WHAT — the end state you want to exist. With
declarative, the tool derives the how, which is exactly what buys you the preview
(plan), the repeatability (idempotency), and the repair (drift reconcile). Keep it
crisp — the next slide shows the same intent both ways. (~2 min)
Then: "Here's the same job — write a greeting file — as a script, then as HCL."
-->

---
layout: two-cols-code
heading: Same job, two paradigms
---

````md magic-move
```bash
#!/usr/bin/env bash
# Imperative: the exact steps, every time.
mkdir -p build
echo "Hello from host-$RANDOM \
  — provisioned imperatively." \
  > build/greeting.txt
cat build/greeting.txt
# Run it twice → a DIFFERENT file.
# No plan. No idempotency. No drift check.
```

```hcl
# Declarative: the desired state.
resource "random_pet" "env" {
  length = 2
}

resource "local_file" "greeting" {
  filename = "${path.module}/build/greeting.txt"
  content  = "Hello from ${random_pet.env.id} — provisioned declaratively.\n"
}
# tofu plan previews. apply is idempotent.
# Edit the file by hand → tofu detects drift.
```
````

::right::

<div class="mt-4">
  <KwCard heading="The script" variant="danger">
    <strong>Steps.</strong> New <code>$RANDOM</code> each run, no preview, no memory
    of what it built. Re-running is a fresh roll of the dice.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="The HCL" kind="resource" variant="ok">
    <strong>State.</strong> The pet name is generated <em>once</em> and stored;
    <code>plan</code> previews, <code>apply</code> is idempotent, and drift is
    detected and reconciled.
  </KwCard>
  </div>
</div>

<!--
Say: Same job — write a greeting file — expressed both ways via magic-move. The
bash version is imperative: mkdir, echo with $RANDOM, cat. Run it twice and you get
a different file; there's no plan, no idempotency, no memory. Morph to the HCL: a
random_pet generates a stable identity once and stores it in state, and a local_file
declares the file's desired content. Now tofu plan previews before acting, apply is
idempotent, and if someone hand-edits the file tofu detects the drift and puts it
back. This is the HCL you build in Lab 01 — the lab's tracked `main.tf` is the source of truth (the slide is illustrative). (~5 min)
Then: "So why do we type 'tofu' and not 'terraform'? Here's the fork."
-->

---
clicks: 3
---

<span class="kw-kicker">The fork, on a timeline</span>

# HashiCorp → OpenTofu

<div class="mt-8 space-y-4">
  <div class="flex items-center gap-4">
    <KwChip>2023-08-10</KwChip>
    <span>HashiCorp relicenses Terraform <strong>MPL 2.0 → BUSL 1.1</strong> — open source becomes <em>source-available</em>.</span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip variant="warn">2023-08-25</KwChip>
    <span>The community forks the last MPL-2.0 release as <strong>OpenTofu</strong>.</span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip variant="ok">2024-01-10</KwChip>
    <span><strong>OpenTofu 1.6</strong> ships GA — drop-in compatible, under the <strong>Linux Foundation</strong>.</span>
  </div>
</div>

<div v-click class="mt-8 kw-muted text-sm">

That's why the HCL block is still `terraform {}` (compatibility) but the CLI you
run — and everything here — is `tofu`.

</div>

<!--
Say: The fork as a three-beat timeline, revealed click by click. 2023-08-10:
HashiCorp relicenses Terraform from MPL 2.0 to BUSL 1.1 — open source becomes
source-available. 2023-08-25: the community forks the last MPL-2.0 release as
OpenTofu. 2024-01-10: OpenTofu 1.6 ships GA, drop-in compatible, now under the Linux
Foundation. Final reveal: this is exactly why the top-level block is still named
terraform {} for compatibility, but the CLI we run — and everything in this
workshop — is tofu. (~3 min)
Then: "Let's make the licence difference concrete — MPL vs BUSL, side by side."
-->

---
layout: comparison
heading: MPL 2.0 vs BUSL 1.1 — what the licence buys you
leftHeading: OpenTofu
rightHeading: Terraform
leftBadge: 'MPL 2.0'
rightBadge: 'BUSL 1.1'
---

- **Open source** — OSI-approved, no field-of-use limit
- Use, modify, and build a **commercial** product on it freely
- Governed by the **Linux Foundation** (neutral, community)
- HCL- and CLI-**compatible** — low-friction to adopt

::right::

- **Source-available**, not open source
- "Additional use grant" **forbids competing** commercial use
- Each release converts to an older licence only at its **change date**
- Controlled by a **single vendor**

<!--
Say: This is the "why it matters to you" slide. OpenTofu under MPL 2.0 is
OSI-approved open source with no field-of-use limit — you can use, modify, and build
a commercial product on it freely, and it's governed by the neutral Linux
Foundation. Terraform under BUSL 1.1 is source-available, not open source: the code
is visible, but the additional-use-grant forbids using it to compete with the
licensor until each release hits its change date, and it's controlled by a single
vendor. For a team that wants genuinely open, community-governed tooling, OpenTofu
is the answer — and it's compatible, so adopting it is low-friction. (~3 min)
Then: "Now go do it yourself — Lab 01."
-->

---
layout: lab
lab: labs/day-1/01-iac-fork.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 01 — from a shell script to HCL

Run a throwaway imperative script twice and watch it produce a different file each
time. Then apply the **declarative** HCL, prove a re-apply is a **no-op**, hand-edit
the managed file, and watch `tofu` **detect the drift and reconcile** it. Finish by
reading the fork/licensing note.

Every task has a `<details>` spoiler; panic reset is `tofu destroy` + `rm`.

<!--
Say: Set up the lab and its payoff. First feel the imperative pain — run the bash
script twice, get a different file each time. Then apply the declarative HCL and hit
the three things scripts can't do: plan previews, a second apply is a clean no-op,
and when you hand-edit the managed file, tofu detects the drift and puts it back.
Close by reading the short fork/licensing note so the "why tofu" lands. Every task
has a spoiler; panic reset is tofu destroy plus rm — nothing cloud, nothing to leak.
(~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Infrastructure as Code — recap
story: 'Describe the state you want; let the tool make reality match — and know why it says tofu.'
next: 'Next: HCL & building blocks'
---

- Doing infra by hand fails three ways: **not repeatable**, **no preview**, **no drift detection**.
- The evolution: **click-ops → scripts → declarative IaC**, each fixing the last one's pain.
- **Imperative** says *how*; **declarative** says *what* — and the tool previews, repeats, and repairs.
- The **fork**: BUSL relicense (2023-08-10) → OpenTofu fork (2023-08-25) → 1.6 GA (2024-01-10).
- **MPL 2.0** (open, Linux Foundation) vs **BUSL 1.1** (source-available, single vendor) — why we run `tofu`.

<!--
Say: Pull the five threads together. Doing infra by hand fails three ways — not
repeatable, no preview, no drift detection. The evolution went click-ops to scripts
to declarative IaC, each step fixing the prior pain. The core distinction:
imperative says how, declarative says what, and the tool previews, repeats, and
repairs. The fork timeline: BUSL relicense, community fork, 1.6 GA. And the licence
difference — MPL 2.0 open and Linux-Foundation-governed versus BUSL 1.1
source-available and single-vendor — is why we teach the tofu CLI. (~2 min)
Then: transition into S02 — HCL & building blocks.
-->
