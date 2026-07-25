---
layout: section-cover
image: /covers/section-23-conducting-the-fleet.png
day: Day 3
section: '23'
tier: core
---

# Orchestration & ordering

## Run every stack — in the right order

<!--
Say: Discover and generate are done. Two stacks can still plan in the wrong order — app before network — and nothing stops you. Today Terramate walks after/before so dependents wait. Order is the third verb of Day 3. (~1 min)
Then: Name the command that runs across stacks.
-->

---
layout: statement
kicker: 'Run · order'
---

`terramate list` finds stacks. **`terramate run`** executes a command in each —
honouring **`after` / `before`** so the graph stays acyclic.

OpenTofu still owns state. Terramate only chooses **which root, which order**.

<!--
Say: Say it plainly. run is the orchestration verb. after and before are edges on the run-graph. tofu plan and tofu apply still happen inside each stack with that stack's state. Terramate does not merge state or invent a super-backend. (~2 min)
Then: Put the accent on order in the four-phase loop.
-->

---
layout: topology
clicks: 4
---

<span class="kw-kicker">orchestration · order</span>

# Four phases — today is order

<div class="grid grid-cols-4 gap-3 mt-8">
  <KwCard v-click heading="1 · Discover" icon="🔍" variant="plain">
    Find directories that declare <code>stack {}</code> — <strong>S21</strong>.
  </KwCard>
  <KwCard v-click heading="2 · Generate" icon="🧱" variant="plain">
    Emit shared backend/provider HCL — <strong>S22</strong>.
  </KwCard>
  <KwCard v-click heading="3 · Order" icon="🔗" variant="accent">
    Honour <code>after</code> / <code>before</code>; walk the run-graph.
  </KwCard>
  <KwCard v-click heading="4 · Filter" icon="🎯" variant="plain">
    <code>--changed</code> / <code>--tags</code> — <strong>S24</strong>.
  </KwCard>
</div>

<p v-click class="mt-8 text-center text-sm opacity-75">
Static order highlight — <code>TerramateOrchestration</code> remains deferred.
</p>

<!--
Say: Same four-phase loop. Discover and generate stay grey. Order is lit. Filter waits for S24. No Vue animation — static cards on purpose. (~2 min)
Then: Show after and before as two ways to declare the same edge.
-->

---
layout: comparison
leftHeading: after
leftBadge: I wait
rightHeading: before
rightBadge: They wait
---

<span class="kw-kicker">edges</span>

# Two ways to declare order

::left::

```hcl
stack {
  name = "app"
  after = ["tag:networking"]
}
```

App runs **after** every stack tagged
`networking`.

::right::

```hcl
stack {
  name = "network"
  before = ["tag:app"]
}
```

Network runs **before** every stack tagged
`app` — same edge, other end.

<!--
Say: Pick one style and stick to it in a monorepo. Tags keep edges stable when paths move. Paths work too — /stacks/network or ../network — but tags match how S21 taught discovery. A cycle on either form fails the run. (~2 min)
Then: Show the tracked after block learners will run.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · app after network</span>

# App waits for networking

<!-- source: labs/day-3/23-orchestration/stacks/app/stack.tm.hcl -->
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

<CodeNote at="1" label="Stack">Same leaf as S21/S22 — still one OpenTofu root.</CodeNote>
<CodeNote at="2" label="Identity">Name, description, tags unchanged from discovery.</CodeNote>
<CodeNote at="3" label="Stable id">UUID keeps the stack identity across renames.</CodeNote>
<CodeNote at="4" label="Order"> <code>after = ["tag:networking"]</code> — app waits for the network stack.</CodeNote>
<CodeNote at="5" label="Edge">No matching <code>before</code> on network required when this side declares the wait.</CodeNote>

<!--
Say: This is the tracked file. Line with after is the only new field versus S22. Network still has no before — one edge is enough. Slides and lab share this source. (~2 min)
Then: Show how to inspect the run-graph before you run tofu.
-->

---
layout: two-cols-code
heading: Inspect order before you run
---

```bash
terramate list --run-order
# stacks/network
# stacks/app

terramate experimental run-graph
# digraph {
#   n2[label="network"];
#   n1[label="app"];
#   n2->n1;
# }
```

::right::

```bash
terramate run --dry-run -- echo STACK
# Entering stack in /stacks/network
# Entering stack in /stacks/app

terramate run -- tofu plan -input=false -no-color
# network plan, then app plan
```

<!--
Say: list alone is alphabetical-ish discovery order — not run order. --run-order and experimental run-graph show the DAG. dry-run prints Entering stack without executing. Then the same run wraps tofu. (~2 min)
Then: Name the failure mode — a cycle.
-->

---
layout: statement
kicker: 'Break → fix · cycle'
---

A **cycle** (`app after network` **and** `network after app`) makes
`terramate run` fail fast:

`Error: … cycle detected: /stacks/app -> /stacks/network -> /stacks/app`

Read the path. Remove one edge. Re-list with `--run-order`.

<!--
Say: This is today's break→fix. Mutual after is the classic footgun. run-graph paints cycle edges red. Do not invent a third stack to "solve" it — delete one dependency. (~2 min)
Then: Hands-on — declare, inspect, run tofu, then break and fix a cycle.
-->

---
layout: lab
lab: labs/day-3/23-orchestration.md
duration: 30 min
env: 'mock ✓ (no docker)'
---

# Lab — order stacks, then break a cycle

- Extend the S22 codegen stacks with `after` on app.
- `terramate list --run-order` + `experimental run-graph` + ordered `tofu`.
- Break→fix: ordering cycle → read the error → remove one edge.

<!--
Say: Mock only — no Docker. Learners copy the workdir, commit with the one-shot git identity pin, prove network-then-app, run tofu init/plan across stacks, then add a reverse after and watch the cycle error. Spoilers match terramate 0.17.x. (~30 min)
Then: Debrief — order is a DAG; cycles fail closed.
-->

---
layout: recap
next: S24 · Change detection
---

<span class="kw-kicker">recap · order</span>

# Orchestration — operating rules

- **`terramate run`** executes a command in every selected stack.
- Declare order with **`after` / `before`** (tags or paths); keep the graph a DAG.
- Inspect with **`list --run-order`** and **`experimental run-graph`** before apply.
- A **cycle** fails the run — remove an edge; do not ignore the error.

<p v-click class="mt-8 text-xl font-semibold">Order the fleet — then run <code>tofu</code> once per stack.</p>

<!--
Say: Close on the DAG. Next, S24 filters which stacks enter that ordered run with --changed and --tags. (~2 min)
Then: S24 · Change detection.
-->
