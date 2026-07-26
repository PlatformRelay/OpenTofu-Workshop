---
layout: section-cover
image: /covers/section-24-only-what-moved.png
day: Day 3
section: '24'
tier: recommended
---

# Change detection & filtering

## Run only what moved

<!--
Say: Order is settled. Running every stack on every PR still burns the room. Today Terramate filters the run-graph — Git change detection and tags — so a monorepo PR plans only what it touched. Filter is the fourth verb of Day 3. (~1 min)
Then: Name the flags that select stacks.
-->

---
layout: statement
kicker: 'Run · filter'
---

`terramate run` can select stacks. **`--changed`** keeps stacks Git says moved.
**`--tags`** keeps stacks that carry a tag.

OpenTofu still owns state. Terramate only chooses **which root enters the run**.

<!--
Say: Say it plainly. Filter sits in front of order. A PR that edits one leaf should not plan the whole fleet. Tags carve long-lived slices — env, team, layer — without a second DAG. tofu plan still runs inside each selected stack. (~2 min)
Then: Put the accent on filter in the four-phase loop.
-->

---
clicks: 4
---

<span class="kw-kicker">orchestration · filter</span>

# Four phases — today is filter

<TerramateOrchestration phase="filter" :step="$clicks" class="mt-8" />

<div v-click="4" class="mt-8 kw-muted text-sm text-center">

Discover, generate, and order are done. Filter selects which stacks enter the ordered run.

</div>

<!--
Say: Same four-phase loop. Discover, generate, and order stay grey. Filter is lit. (~2 min)
Then: Show why default_branch matters for Git change detection.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · git default branch</span>

# Change detection baselines on `main`

<!-- source: labs/day-3/24-change-detection/terramate.tm.hcl -->
```hcl {1|2|3-8|4-6|1-9}
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

<CodeNote at="1" label="Root">Same project root as S20–S23 — one Terramate config.</CodeNote>
<CodeNote at="2" label="CLI pin">required_version keeps the binary coherent across machines.</CodeNote>
<CodeNote at="3" label="Git">config.git steers change detection.</CodeNote>
<CodeNote at="4" label="Base">default_branch = "main" — feature commits compare against main.</CodeNote>
<CodeNote at="5" label="PR shape">Branch off main, change one stack, run with --changed.</CodeNote>

<!--
Say: This is the tracked file learners already carried from S20. default_branch is why a feature branch sees only its diff against main — the monorepo PR story. Without a second commit, --changed refuses to guess. (~2 min)
Then: Show tags on the stack leaf used for --tags.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · stack tags</span>

# Tags are filter handles

<!-- source: labs/day-3/24-change-detection/stacks/app/stack.tm.hcl -->
```hcl {1|2-4|5|6|1-7}
stack {
  name        = "app"
  description = "Application workload"
  tags        = ["app", "compute"]
  id          = "22222222-2222-2222-2222-222222222222"
  after       = ["tag:networking"]
}
```

::notes::

<CodeNote at="1" label="Stack">Same leaf as S23 — order edge stays.</CodeNote>
<CodeNote at="2" label="Identity">Name and description unchanged.</CodeNote>
<CodeNote at="3" label="Tags">app / compute — --tags=app selects this stack.</CodeNote>
<CodeNote at="4" label="Stable id">UUID keeps identity across renames.</CodeNote>
<CodeNote at="5" label="Order">after still applies when this stack is selected.</CodeNote>

<!--
Say: Tags were discovery labels in S21. Today they are run filters. Combine with --changed when a PR should only plan the app leaf that moved. Order still applies inside the filtered set. (~2 min)
Then: Show the command shapes side by side.
-->

---
layout: two-cols-code
heading: Filter the run — changed vs tags
---

```bash
# Feature branch vs main (Git)
terramate list --changed --why
# stacks/app - stack has unmerged changes

terramate run --changed -- echo ONLY_APP
# Entering stack in /stacks/app

terramate run --changed -- tofu plan -input=false -no-color
```

::right::

```bash
# Long-lived slices (tags)
terramate list --tags=app
# stacks/app

terramate run --tags=networking -- echo NET
# Entering stack in /stacks/network

# Combine — intersection
terramate run --changed --tags=app -- echo BOTH
```

<!--
Say: Left is the PR path — list --why explains the selection. Right is env/team slicing. Flags combine as intersection: changed and tagged. Empty selection is success with no Entering lines — not a crash. (~2 min)
Then: Name why this matters in a monorepo.
-->

---
layout: statement
kicker: 'Monorepo · PR scope'
---

A monorepo PR that touches **one** stack should not plan **every** stack.

`--changed` is the CI gate: plan what the branch moved; leave the rest quiet.

<!--
Say: This is the operating rule for Day-3 scale. Full fleet runs stay for nightlies or releases. PR checks use --changed so review stays fast and blast radius stays small. Tags carve standing subsets when Git change is the wrong axe. (~2 min)
Then: Name the dirty-worktree footgun before the lab.
-->

---
layout: statement
kicker: 'Edge · dirty worktree'
---

Uncommitted files make **`terramate run --changed`** fail closed:

`Error: repository has uncommitted files`

`list --changed --why` still explains selection. Commit or discard, then re-run.

<!--
Say: This is today's edge, not a cycle. Change detection refuses a dirty tree so CI and local stays honest. list can still show why; run will not. Fix is commit with the one-shot identity pin — or discard — never invent a flag to ignore dirt in the lab. (~2 min)
Then: Hands-on — baseline, change one stack, prove filters, hit the dirty edge.
-->

---
layout: lab
lab: labs/day-3/24-change-detection.md
duration: 25 min
env: 'mock ✓ (no docker)'
---

# Lab — change one stack, prove the filter

- Baseline commit on `main`, then a feature branch.
- Change **app** only; prove `terramate run --changed` skips network.
- Filter with `--tags`; document dirty-worktree fail-closed.

<!--
Say: Mock only — no Docker. Learners copy the S23-shaped workdir, pin git identity on every commit, prove only the changed stack runs, then leave an uncommitted edit and watch run --changed refuse. Spoilers match terramate 0.17.x. (~25 min)
Then: Debrief — filter before order; dirty trees fail closed.
-->

---
layout: recap
next: S25 · Terramate in CI
---

<span class="kw-kicker">recap · filter</span>

# Change detection — operating rules

- **`--changed`** selects stacks Git reports as moved vs `default_branch`.
- **`--tags`** selects long-lived slices; combine with `--changed` as intersection.
- PR-scoped runs keep monorepo CI cheap — plan only what the branch touched.
- A **dirty worktree** fails `run --changed` — commit or discard, then retry.

<p v-click class="mt-8 text-xl font-semibold">Filter the fleet — then run <code>tofu</code> only where it matters.</p>

<!--
Say: Close on selection. Next, S25 wires --changed into CI and peeks at Cloud as observability — still no state management. (~2 min)
Then: S25 · Terramate in CI.
-->
