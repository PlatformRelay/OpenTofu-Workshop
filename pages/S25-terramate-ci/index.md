---
layout: section-cover
image: /covers/section-25-the-orbital-watch.png
day: Day 3
section: '25'
tier: optional
---

# Terramate in CI + Cloud

## Wire `--changed` into the PR gate — Cloud watches, state stays yours

<!--
Say: Filter is proven locally. Today we put --changed into CI so every PR plans only what the branch moved, then peek at Terramate Cloud as an observability SaaS — drift, misconfig, dashboards — still without taking state. Optional deep-dive; skip if the room is short after S24. (~1 min)
Then: Name what a monorepo PR gate must do.
-->

---
layout: statement
kicker: 'CI · PR gate'
---

A monorepo PR should **plan only stacks Git says moved**.

`terramate run --changed -- tofu plan …` is the gate — same filter as S24,
now on every pull request.

<!--
Say: Say the operating rule once. Nightlies can walk the fleet. PR checks use --changed so review stays fast and blast radius stays small. OpenTofu still plans inside each selected stack; Terramate only chooses which roots enter. (~2 min)
Then: Show the two checkout gotchas that break change detection in Actions.
-->

---
layout: topology
clicks: 3
---

<span class="kw-kicker">S25 · CI prerequisites</span>

# Change detection needs history

<div class="grid grid-cols-3 gap-3 mt-8">
  <KwCard v-click heading="1 · Full history" icon="📚" variant="warn">
    <code>actions/checkout</code> with <code>fetch-depth: 0</code> — shallow
    clones hide <code>main</code>.
  </KwCard>
  <KwCard v-click heading="2 · Default branch" icon="🌿" variant="plain">
    Same <code>config.git.default_branch = "main"</code> as S24.
  </KwCard>
  <KwCard v-click heading="3 · <code>--changed</code>" icon="🎯" variant="accent">
    <code>list</code> then <code>run --changed -- tofu …</code> — never the
    whole fleet on a PR.
  </KwCard>
</div>

<p class="mt-8 text-center text-sm opacity-75">
Paper fixture under <code>labs/day-3/25-terramate-ci-cloud/</code> — no Actions runner required.
</p>

<!--
Say: Three prerequisites. Full git history so the tip can diff against main. The Terramate default_branch pin learners already carry. And the --changed flag on both list and run. A shallow checkout is the classic false-green: the job starts, but change detection cannot see the base. (~3 min)
Then: Walk the repaired workflow YAML.
-->

---
layout: code-walkthrough
---

<span class="kw-kicker">taught artifact · PR workflow</span>

# `--changed` on every pull request

```yaml {none|1-4|6-8|10-16|18-21}
# Fixed shape — labs/day-3/25-terramate-ci-cloud.md spoilers
on:
  pull_request:
    branches: [main]

- uses: actions/checkout@v4
  with:
    fetch-depth: 0          # history for change detection

- uses: terramate-io/terramate-action@v3
  with:
    version: "0.17.1"
- uses: opentofu/setup-opentofu@v1
  with:
    tofu_version: "1.10.3"
    tofu_wrapper: false

- run: terramate list --changed
- run: |
    terramate run --changed -- tofu init -input=false
    terramate run --changed -- tofu plan -input=false -no-color
```

::notes::

<CodeNote at="1" label="Trigger">PR against main — the monorepo gate.</CodeNote>
<CodeNote at="2" label="History">fetch-depth: 0 — required for --changed vs default_branch.</CodeNote>
<CodeNote at="3" label="CLIs">Pin Terramate + OpenTofu; tofu_wrapper false avoids wrapper clashes.</CodeNote>
<CodeNote at="4" label="Filter">list then run --changed — plan only what moved.</CodeNote>

<!--
Say: Point at the repaired shape. Trigger on pull_request to main. Checkout with fetch-depth zero. Install pinned Terramate and OpenTofu. List changed stacks, then run init and plan only on that set. The lab starts from a broken fixture that plans the whole fleet on a shallow clone — learners repair both defects. (~3 min)
Then: Separate CI from Cloud.
-->

---
layout: comparison
leftHeading: Terramate CLI in CI
leftBadge: OSS · your runner
rightHeading: Terramate Cloud
rightBadge: SaaS · optional
---

```text
Your GitHub Actions (or other CI)
  · checkout + fetch-depth: 0
  · terramate list --changed
  · terramate run --changed -- tofu …
  · ASCII plan on the PR
```

::right::

```text
Observability SaaS on top of the CLI
  · drift detection dashboards
  · misconfiguration signals
  · stack / run visibility
  · sync flags optional — not required
```

<!--
Say: Left is free and sufficient for the workshop gate — CLI in CI you already own. Right is Terramate Cloud: SaaS observability — drift, misconfig, dashboards — that can sync from the same CLI when you opt in. Core lab never requires an account. (~2 min)
Then: Drift as a concept without a signup.
-->

---
layout: statement
kicker: 'Cloud · drift concept'
---

**Drift** = live infrastructure diverged from what the last apply recorded.

Cloud surfaces that signal on a dashboard. Detection still runs
`tofu plan` / detailed-exitcode against **your** backend — the SaaS watches;
it does not become the state store.

<!--
Say: Define drift without selling the product. Reality moved outside OpenTofu — someone clicked the console, another tool applied, a resource was deleted. A plan with detailed exit code finds the delta. Terramate Cloud can aggregate those signals. The backend path, lock, and encryption remain yours. Static concept is enough — no live tenant. (~2 min)
Then: Repeat the Day-3 non-negotiable.
-->

---
layout: statement
kicker: 'Non-negotiable · again'
---

Terramate **still does NOT manage state**.

CI invokes `tofu` against the backend you configured. Cloud observes runs and
drift. Neither relocates locking, encryption, or the state file.

<!--
Say: Same sentence as S20 — say it again because Cloud looks like a control plane. Orchestration and observability are not a state service. OpenTofu owns state; Terramate chooses which stacks run and can report what happened. Kill the TACO-confusion before the lab. (~2 min)
Then: Hands-on — repair the fixture, prove --changed locally, Cloud read-only.
-->

---
layout: lab
lab: labs/day-3/25-terramate-ci-cloud.md
duration: 25 min
env: 'mock ✓ (paper + fixture · no docker)'
---

# Lab — wire `--changed` into CI

- Spot shallow-checkout + missing `--changed` defects in the fixture.
- Repair the workflow; prove selection locally (S24 shape).
- Cloud is **read-only / conceptual** — **no signup**.

<!--
Say: Paper plus fixture — no Docker, no Actions minutes, no Cloud account. Learners repair the YAML, validate it with actionlint when available, then replay the S24 git baseline in a disposable root to prove the same --changed command the workflow will run. (~25 min)
Then: Debrief — CI filter, Cloud observe, state stays with tofu.
-->

---
layout: recap
next: S26 · Capstone
---

<span class="kw-kicker">recap · CI + Cloud</span>

# PR gate + observability — operating rules

- PR CI: `fetch-depth: 0` + `terramate run --changed -- tofu …`.
- Shallow clones and fleet-wide `run` are the classic false greens.
- Terramate Cloud = drift / misconfig / observability SaaS — optional.
- It **still does not manage state** — backends stay with OpenTofu.

<p v-click class="mt-8 text-xl font-semibold">Filter in CI. Observe in Cloud. Keep state where <code>tofu</code> put it.</p>

<!--
Say: Close on three verbs — filter in CI, observe in Cloud, keep state with OpenTofu. Optional section complete; next is the capstone that ties the three days together. (~2 min)
Then: S26 · Capstone.
-->
