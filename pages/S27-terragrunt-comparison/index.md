---
layout: section-cover
image: /covers/placeholder-section.svg
aiGenerated: false
day: Day 3
section: '27'
tier: optional
---

# Terragrunt vs Terramate

## Two orchestrators, one decision — an optional appendix

Day 3 scaled the monorepo with **Terramate**. **Terragrunt** attacks the same
"many roots" problem with a different philosophy. This short appendix maps one
onto the other — so you can choose a tool, or defend the one already chosen.

<!--
Say: Frame this as an appendix, not a second Day-3 track. The room has just
scaled a monorepo with Terramate — stacks, codegen, ordering, change detection.
Terragrunt is the other well-known orchestrator in this space, and someone in
every cohort asks about it. In about twenty minutes we map its concepts onto the
Terramate workflow they already know, name where each tool fits, and state
explicitly which path this workshop takes. There is no Terragrunt install and no
Terragrunt lab chain — this is a comparison, not a course. (~1 min)
Then: "Start from the problem both tools exist to solve."
-->

---
layout: statement
kicker: 'The problem frame'
---

**Many roots, one engine.** Backends and providers repeated per leaf, an
execution order that matters, CI that should touch only what changed.

`tofu` plans and applies **one root at a time**. Terragrunt and Terramate are
two answers to everything *around* that — **neither replaces the CLI**.

<!--
Say: Re-anchor the S20 problem statement, because both tools are answers to it.
Once a repo has many roots, three pains arrive together: duplicated backend and
provider boilerplate, an order between roots that the CLI does not know about,
and CI runs that should touch only what changed. OpenTofu itself operates one
root at a time — that is by design. Terragrunt and Terramate are both
orchestration layers wrapped around that engine, and neither replaces tofu:
every real plan and apply is still the CLI you already know. (~2 min)
Then: "So what does each tool actually own?"
-->

---
layout: comparison
leftHeading: Terragrunt
leftBadge: wrapper at runtime
rightHeading: Terramate
rightBadge: generate before commit
---

<span class="kw-kicker">What each owns — and leaves to `tofu`</span>

- **Unit** = a directory with `terragrunt.hcl`.
- **DRY** via `remote_state` / `generate` blocks — backend and provider files
  are written into the unit **at run time**.
- **Order** via `dependency` blocks; `run --all` (formerly `run-all`)
  walks the tree, wiring
  `inputs` from other units' outputs.
- You type `terragrunt`; it **wraps** every `tofu` invocation.

::right::

- **Stack** = a directory with `stack.tm.hcl`.
- **DRY** via `generate_hcl` + `globals` — `_backend.tf` / `_providers.tf`
  are generated **before commit** and reviewed like any file.
- **Order** via `after` / `before` + Git-based `--changed` selection.
- You type `terramate run -- tofu …`; the commands stay **plain `tofu`**.

<!--
Say: Walk the panels in pairs. Both tools name the same unit of work — a
directory: Terragrunt calls it a unit with a terragrunt.hcl, Terramate calls it
a stack with a stack.tm.hcl. Both kill the DRY tax by generating backend and
provider boilerplate — the difference is WHEN: Terragrunt writes those files at
run time as it wraps the CLI, Terramate generates them before commit so they are
reviewed in the PR like any other file. Both order the fleet — Terragrunt with
dependency blocks and run dash dash all, Terramate with after/before edges plus Git-based
change detection. And the last pair is the philosophy in one line: with
Terragrunt you type terragrunt and it wraps every tofu call; with Terramate you
still type plain tofu behind terramate run. Both leave plan, apply, and state to
the engine. (~5 min)
Then: "Turn that into a decision table."
-->

---

<span class="kw-kicker">The decision</span>

# When each tool fits

<table class="kw-tg-table mt-3">
  <thead>
    <tr>
      <th>Axis</th>
      <th>Terragrunt fits when…</th>
      <th>Terramate fits when…</th>
    </tr>
  </thead>
  <tbody>
    <tr v-click>
      <td><strong>Existing estate</strong></td>
      <td>The org already runs a <code>terragrunt.hcl</code> tree — momentum
        and team knowledge are real assets.</td>
      <td>You start from plain <code>tofu</code> roots (this workshop's
        monorepo) and want to keep them plain.</td>
    </tr>
    <tr v-click>
      <td><strong>Generated files</strong></td>
      <td>Run-time generation is acceptable — boilerplate never lands in
        the repo.</td>
      <td>You want generated code <strong>reviewed in PRs</strong> and
        drift-checked (<code>generate --detailed-exit-code</code>).</td>
    </tr>
    <tr v-click>
      <td><strong>Selection model</strong></td>
      <td><code>run --all</code> on a subtree; output-wiring between units via
        <code>dependency</code>.</td>
      <td>Git-based <code>--changed</code> + <code>--tags</code> filters —
        CI plans only what moved (S24/S25).</td>
    </tr>
    <tr v-click>
      <td><strong>CLI surface</strong></td>
      <td>A wrapper CLI is fine; commands become
        <code>terragrunt …</code>.</td>
      <td>Learners/tooling keep typing <strong>plain
        <code>tofu</code></strong> behind <code>terramate run</code>.</td>
    </tr>
  </tbody>
</table>

<div v-click class="mt-3 kw-muted text-sm">

Both are OSS, both are OpenTofu-friendly, both are **defensible**. The axes
steer the choice — not a winner list.

</div>

<style>
.kw-tg-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.78rem;
}
.kw-tg-table th,
.kw-tg-table td {
  border: 1px solid var(--kw-border);
  padding: 0.4rem 0.6rem;
  text-align: left;
  vertical-align: top;
}
.kw-tg-table thead th {
  background: var(--kw-panel-2);
  color: var(--kw-text);
  font-weight: 600;
}
</style>

<!--
Say: Reveal one axis at a time and keep it honest — both tools are open source,
both drive OpenTofu, and both are defensible choices. Axis one, the estate you
already have: an org with a working terragrunt.hcl tree has momentum, and
throwing that away has a cost; a plain-tofu monorepo like ours has nothing to
migrate. Axis two, generated files: Terragrunt generates at run time so
boilerplate never lands in the repo; Terramate generates before commit so the
boilerplate is reviewed and drift-checked in CI — that is the philosophy split
that decides most adoptions. Axis three, selection: run dash dash all on a subtree versus
Git-based changed-plus-tags filters. Axis four, the CLI surface your team types
every day: a wrapper, or plain tofu behind terramate run. (~4 min)
Then: "One confusion to kill before the lab."
-->

---
layout: statement
kicker: 'The confusion to kill'
---

**Neither tool is a TACO. Neither hosts your state.**

Terragrunt's `remote_state` block and Terramate's `generate_hcl` both only
**write backend configuration** — the state itself lives wherever that backend
points. RBAC, policy, audit? That is the S11 platform layer, not these CLIs.

<!--
Say: This is the misconception the lab breaks on purpose. Terragrunt's
remote_state block looks like it "gives you remote state" — it does not. It
writes a backend.tf into the unit, exactly like Terramate's generate_hcl writes
one into the stack. In both cases the state file lives wherever that backend
points — S3, a local path, whatever you configured — and locking and encryption
stay OpenTofu's job, the S20 non-negotiable. And neither CLI gives you RBAC,
policy gates, or an audit trail: that is the TACO platform layer from S11.
Orchestrator, engine, platform — three layers, keep them separate. (~3 min)
Then: "Prove it on the fixture — the mapping lab."
-->

---
layout: lab
lab: labs/day-3/27-terragrunt-comparison.md
duration: 20 min
env: 'mock ✓ (paper + fixture · no docker)'
---

# Lab 27 — map Terragrunt onto Terramate

A **read-only fixture** exercise: inspect a small `terragrunt.hcl` tree, map
three Terragrunt concepts onto the S21–S23 Terramate workdirs, and break→fix
the planted claim that Terragrunt is a state host.

No Terragrunt install, no Docker, no `tofu apply` — `cat` and `grep` only.

<!--
Say: Set up the lab. There is nothing to install and nothing to apply — the
fixture Terragrunt tree is read-only, and the Terramate side is the S21 to S23
workdirs they already used. Task one: map unit to stack, remote_state and
generate to generate_hcl, dependency and run dash dash all to after edges and changed
filters — with grep evidence for every mapping. Task two is the break→fix: the
fixture plants the claim that Terragrunt stores your state; learners disprove it
from the config itself and correct it. Twenty minutes, spoilers throughout.
(~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Terragrunt vs Terramate — recap
story: 'Two orchestrators around the same engine — this workshop teaches the Terramate path.'
next: 'End of the superset — the Day-3 track closed with S26.'
---

- **Same problem frame:** many roots, duplicated boilerplate, ordering,
  changed-only CI — and `tofu` untouched underneath both tools.
- **Terragrunt:** units + `terragrunt.hcl`, run-time `generate`/`remote_state`,
  `dependency` wiring, a **wrapper** CLI.
- **Terramate:** stacks + `stack.tm.hcl`, **pre-commit** `generate_hcl`,
  `after`/`before` + Git `--changed`, plain `tofu` commands.
- **Neither is a TACO, neither hosts state** — backends, locking, and
  encryption stay with OpenTofu; platforms are the S11 layer.
- **This workshop's path is Terramate** (S20–S26): reviewed codegen, Git-based
  change detection, and plain `tofu` fit the monorepo we built. Terragrunt
  remains a defensible choice for an estate that already speaks it.

<!--
Say: Close the appendix with the mapping in one breath. Same problem frame —
many roots around one engine. Terragrunt answers with units, run-time
generation, dependency wiring, and a wrapper CLI; Terramate answers with
stacks, pre-commit codegen you review in PRs, ordering edges plus Git-based
change detection, and plain tofu commands. Neither tool is a TACO and neither
hosts state — that stays with OpenTofu, and platforms are the S11 layer. And
say the closer explicitly: this workshop's path is Terramate — it is what
S20 through S26 taught and what the capstone runs — while Terragrunt remains a
defensible choice where an estate already speaks it. (~2 min)
Then: this appendix ends the superset deck — hand back to the Day-3 wrap.
-->
