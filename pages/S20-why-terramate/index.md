---
layout: section-cover
image: /covers/section-20-the-sprawling-frontier.png
day: Day 3
section: '20'
tier: core
---

# Why Terramate

## Scale the monorepo without giving away your state

<!--
Say: Day 3 opens on the scaling problem. You can already author, test, and pipeline a single OpenTofu root. The moment you have many roots — many backends, many provider blocks, an order that matters — copy-paste becomes the default tax. Terramate is the OSS orchestrator we use above tofu for the rest of the day. The non-negotiable claim up front: it does not manage state. (~1 min)
Then: Name the three pains that show up when IaC scales.
-->

---

<span class="kw-kicker">S20 · IaC at scale</span>

# Three pains show up together

<div class="kw-cols-3 mt-4">
  <KwCard heading="Many stacks" kind="module" variant="warn">
    One root per env, team, or blast-radius boundary. Each leaf is its own
    <code>tofu</code> run with its own state file.
  </KwCard>
  <KwCard heading="DRY tax" kind="state" variant="danger">
    Backends and providers get <strong>copied</strong> into every leaf. A pin
    bump becomes a multi-file PR.
  </KwCard>
  <KwCard heading="Ordering" kind="validation" variant="accent">
    Network before app, shared data before consumers. Hand-rolled scripts
    forget edges; CI runs the wrong subset.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Modules reuse <em>logic</em>. They do not orchestrate <em>many roots</em>. That
is a different layer.

</div>

<!--
Say: Scaling IaC is not one problem — it is three that arrive together. Many stacks means many tofu runs and many state files so blast radius stays small. The DRY tax is the copy-pasted backend and provider boilerplate that rots between leaves. Ordering is the dependency graph across stacks that a single shell script always gets wrong under pressure. Modules help reuse logic inside a root; they do not discover, generate, order, or filter many roots. (~3 min)
Then: Define what Terramate is — and what it is not.
-->

---
layout: statement
kicker: 'What it is'
---

**Terramate** is an open-source **orchestrator** for OpenTofu (and Terraform)
monorepos.

It discovers stacks, generates shared HCL, orders runs, and filters what
changed — then shells out to **`tofu`**.

<!--
Say: Put the product in one sentence. Terramate is an OSS orchestrator for OpenTofu and Terraform monorepos. Its job is discovery, codegen, ordering, and change filtering — then it invokes the tofu CLI you already teach. It is not a replacement for OpenTofu, and it is not a TACO SaaS you must adopt to get value from the CLI. (~2 min)
Then: The claim that must stand alone on the next slide.
-->

---
layout: statement
kicker: 'Non-negotiable'
---

Terramate **does NOT manage state**.

Your backend, locking, and encryption stay with **OpenTofu** — and whatever CI
or remote backend you already trust.

<!--
Say: Say it plainly and pause. Terramate does not store state, does not replace your backend block, and does not take over locking or encryption. Those remain OpenTofu concerns — local, S3, or whatever remote you configured — plus the CI and access controls around them. Learners who confuse orchestration with a TACO state service will fight the tool all day; kill that confusion now. (~2 min)
Then: Show where it sits relative to tofu.
-->

---
layout: topology
clicks: 4
---

<span class="kw-kicker">S20 · layering</span>

# Terramate sits above `tofu`

<div class="grid grid-cols-4 gap-3 mt-8">
  <KwCard v-click heading="1 · Your VCS" icon="📦" variant="plain">
    Monorepo of stack directories — one git history, many roots.
  </KwCard>
  <KwCard v-click heading="2 · Terramate" icon="🧭" variant="accent">
    Discover · generate · order · filter — then invoke the CLI.
  </KwCard>
  <KwCard v-click heading="3 · OpenTofu" icon="⚙️" variant="ok">
    <code>tofu plan</code> / <code>apply</code> per stack — owns the engine.
  </KwCard>
  <KwCard v-click heading="4 · Backend" icon="🔐" variant="warn">
    State, lock, encryption — still yours, unchanged by Terramate.
  </KwCard>
</div>

<p v-click class="mt-8 text-center text-xl font-semibold">Orchestrate the runs. Do not relocate the state.</p>

<!--
Say: Four layers, left to right. VCS holds many stack directories. Terramate reads that tree, generates shared boilerplate, orders dependent runs, and filters to what changed. OpenTofu remains the engine that plans and applies each stack. The backend — state, lock, encryption — is still the one you configured; Terramate does not move it. The closing line is the operating rule for Day 3. (~3 min)
Then: Show the before tree that motivated the tool.
-->

---
layout: comparison
leftHeading: Before
leftBadge: copy-paste
rightHeading: After
rightBadge: orchestrated
---

<span class="kw-kicker">monorepo tree</span>

# Same leaves — different tax

::left::

```text
stacks/
  network/
    backend.tf      ← duplicated
    providers.tf    ← duplicated
    main.tf
  app/
    backend.tf      ← duplicated
    providers.tf    ← duplicated
    main.tf
```

::right::

```text
terramate.tm.hcl
stacks/
  network/
    stack.tm.hcl    ← S21
    main.tf         ← stack-specific
    _gen/*.tf       ← S22 codegen
  app/
    stack.tm.hcl
    main.tf
    _gen/*.tf
```

<!--
Say: Left is the pain in the lab fixture — two stacks with byte-identical backend and provider files; only main.tf differs. Right is where Day 3 is headed: a root terramate.tm.hcl, stack metadata in S21, and generated shared HCL in S22 so leaves keep only what is unique. Do not pretend the after tree already exists in the lab — the skeleton starts on the left and grows. (~3 min)
Then: Click through TerramateOrchestration on the next slide — the four-phase loop in one visual.
-->

---
clicks: 4
---

<span class="kw-kicker">orchestration · four phases</span>

# Four phases — one loop

<TerramateOrchestration :step="$clicks" class="mt-8" />

<div v-click="4" class="mt-8 kw-muted text-sm text-center">

**Discover** finds <code>stack {}</code> directories. **Generate** emits shared backend/provider HCL.
**Order** walks <code>after</code> / <code>before</code>. **Filter** runs only what changed or matches a tag.

</div>

<!--
Say: This is the Day-3 red line in four verbs. Discover finds stack directories. Generate writes the duplicated boilerplate once. Order walks after/before so dependents wait. Filter shrinks a PR run to what changed or matches a tag. Each later section highlights one phase; today you only need the shape. (~3 min)
Then: Put the skeleton and the DRY diff into the learners' hands.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · root config</span>

# The monorepo starts here

<!-- source: labs/day-3/20-why-terramate/terramate.tm.hcl -->
```hcl {1-3|5-9|1-11}
terramate {
  required_version = ">= 0.14.0"

  config {
    git {
      default_branch = "main"
    }
  }
}
```

::notes::

<CodeNote at="1" label="Pin">Keep CI and laptops on a compatible Terramate minor.</CodeNote>
<CodeNote at="2" label="Git">Change detection baselines on <code>main</code> (S24).</CodeNote>
<CodeNote at="3" label="Root">This file marks the Terramate project root after <code>git init</code>.</CodeNote>

<!--
Say: Point at the tracked root config in the lab workdir. required_version keeps the CLI coherent across machines. config.git.default_branch prepares change detection for later. Learners will copy this directory into a disposable git root so Terramate treats it as the project root — nested under the workshop repo alone is not enough. (~2 min)
Then: Lab time — PATH guard, DRY diff, disposable init, empty list.
-->

---
layout: lab
lab: labs/day-3/20-why-terramate.md
duration: 25 min
env: 'mock ✓ (no docker)'
---

# Lab — init the monorepo; feel the DRY pain

- Fail loud if `terramate` is missing → run `task setup`.
- Diff the duplicated `backend.tf` / `providers.tf` across `network` and `app`.
- Copy the skeleton to a disposable git root; `terramate list` stays empty until S21.

<!--
Say: Learners stay on mock — no Docker. First they prove Terramate is on PATH or get an explicit task setup pointer. Then they diff the tracked duplicates to feel the tax. Finally they copy the skeleton, git init, and see an empty terramate list because stack blocks arrive in S21. Spoilers match a real terramate 0.17.x run. (~25 min)
Then: Debrief with the operating rule for Day 3.
-->

---
layout: recap
next: S21 · Stacks
---

<span class="kw-kicker">recap · orchestration ≠ state</span>

# Why Terramate — operating rules

- Many stacks + DRY tax + ordering = the scaling problem modules do not solve.
- Terramate orchestrates **above** `tofu`: discover → generate → order → filter.
- It **does not manage state** — backends, locks, and encryption stay with OpenTofu.
- Today's lab leaves a monorepo skeleton; S21 turns directories into stacks.

<p v-click class="mt-8 text-xl font-semibold">Orchestrate the runs. Keep the state where it already lives.</p>

<!--
Say: Close Day 3's opening beat. The problem is multi-root scale, not missing modules. Terramate is the OSS orchestrator above tofu. State remains yours. Next, S21 adds stack.tm.hcl so discovery has something to list. (~2 min)
Then: S21 · Stacks.
-->
