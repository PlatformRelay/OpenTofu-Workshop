---
layout: section-cover
image: /covers/section-03-plan-then-raise.png
day: Day 1
section: '03'
tier: core
---

# The core workflow

Four commands run everything you build with OpenTofu: **`init`**, **`plan`**,
**`apply`**, **`destroy`**. Learn to read the plan they produce, and you can
review any change before it touches the world.

<!--
Say: Frame S03. Everything you ever do with OpenTofu rides on four commands —
init, plan, apply, destroy — plus one skill: reading the execution plan they
produce. By the end of this section you can run the full lifecycle and read a plan
line by line: the +/~/- symbols, known-after-apply, and the dependency graph that
orders it all. This is the Terraform-Associate core-workflow objective, start to
finish. (~1 min)
Then: "Start at the top — init, the command that prepares the directory."
-->

---

<span class="kw-kicker">The lifecycle</span>

# Four commands, one loop

<div class="kw-cols-2 mt-4">
  <KwCard heading="init" variant="ok">
    Prepare the directory: install <strong>providers</strong>, write the
    <code>.terraform.lock.hcl</code> <strong>lock file</strong>. Run it once per
    config (and after changing providers/backends).
  </KwCard>
  <KwCard heading="plan" variant="ok">
    Compute the <strong>diff</strong> between your config and reality. A
    <strong>preview</strong> — it changes nothing.
  </KwCard>
  <KwCard heading="apply" variant="ok">
    Execute the plan: <strong>converge</strong> reality to the config, in
    dependency order. Re-running an unchanged config is a <strong>no-op</strong>.
  </KwCard>
  <KwCard heading="destroy" variant="danger">
    Remove everything in state, in <strong>reverse</strong> dependency order.
  </KwCard>
</div>

<div v-click class="mt-5 kw-muted text-sm">

You'll spend almost all your time in **`plan` → `apply`**. `init` is occasional;
`destroy` is for teardown. The graph orders each one — you never declare order
yourself.

</div>

<!--
Say: The four commands, each with one job. init prepares the directory — installs
providers and writes the lock file — and you run it once per config, or again when
providers or backends change. plan computes the diff between config and reality and
previews it without touching anything. apply executes that plan, converging reality
to the config in dependency order, and a re-run with no changes does nothing.
destroy removes everything in state in reverse order. Click: in practice you live
in the plan-apply loop; init is occasional and destroy is teardown — and the
dependency graph orders all of them for you. (~3 min)
Then: "Let's do them in order, starting with init and the lock file it writes."
-->

---
layout: code-walkthrough
heading: 'init — providers + the lock file'
---

```console
$ tofu init

Initializing provider plugins...
- Installing hashicorp/random v3.9.0...
- Installing hashicorp/local v2.9.0...
- Installed hashicorp/random v3.9.0 (signed, key ID 0C0AF313E5FD9F80)
- Installed hashicorp/local v2.9.0 (signed, key ID 0C0AF313E5FD9F80)

OpenTofu has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository...

OpenTofu has been successfully initialized!
```

<div class="kw-cols-2 mt-4">
  <KwCard heading="Providers" kind="provider" variant="ok">
    <code>init</code> reads <code>required_providers</code>, downloads each plugin
    into <code>.terraform/</code>, and <strong>verifies its signature</strong>.
  </KwCard>
  <KwCard heading=".terraform.lock.hcl" kind="state" variant="ok">
    Pins the exact <strong>versions + checksums</strong> so everyone (and CI)
    resolves the same plugins. <strong>Commit it</strong> — it's OpenTofu's
    <code>package-lock.json</code>.
  </KwCard>
</div>

<!--
Say: init prepares the working directory. It reads required_providers, downloads
each plugin into .terraform/, and verifies the signing key. The output you want to
notice is the lock file: init writes .terraform.lock.hcl pinning the exact versions
and checksums it chose. Commit that file — it's the equivalent of package-lock.json,
and it's what guarantees you and CI resolve identical providers. Provider versions
will drift as the registry moves; that's exactly why the lock file exists. (~3 min)
Then: "Directory ready — now the command you'll run most: plan."
-->

---
layout: code-annotated
heading: 'Reading a plan — the +/~/- symbols'
lab: labs/day-1/03-core-workflow.md
---

```console {none|1-3|2|3|7,9|12|all}
Resource actions are indicated with the following symbols:
  + create
  -/+ destroy and then create replacement

  # local_file.manifest will be created
  + resource "local_file" "manifest" {
      + content  = (known after apply)
      + filename = "./build/manifest.txt"
      + id       = (known after apply)
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

::notes::

<CodeNote at="1" label="the legend">
  Every plan opens by listing the <strong>symbols it will use</strong>. Read this
  first, then scan the body.
</CodeNote>

<CodeNote at="2" label="+ create" variant="ok">
  A new resource. <code>~</code> would be <strong>update</strong>,
  <code>-</code> <strong>destroy</strong>.
</CodeNote>

<CodeNote at="3" label="-/+ replace" variant="warn">
  Can't update in place — OpenTofu will <strong>destroy then recreate</strong>.
  Watch for these.
</CodeNote>

<CodeNote at="4" label="(known after apply)">
  A value that <strong>doesn't exist yet</strong> — computed by a resource that
  hasn't been created. Resolves at apply time.
</CodeNote>

<CodeNote at="5" label="the summary line" variant="ok">
  <code>N to add / change / destroy</code>. <strong>Read this line first</strong> on
  every plan — it's the whole change in one line.
</CodeNote>

<!--
Say: This is the skill of the section — reading a plan. Walk the clicks. First the
legend: every plan lists the symbols it will use, so read that before the body. Plus
create, tilde update, minus destroy — and the compound minus-slash-plus meaning
destroy-then-recreate when a change can't be done in place. Then known-after-apply:
a value that doesn't exist yet because the resource that computes it hasn't been
created — it resolves at apply. Finally the summary line, N to add, change, destroy:
read THAT first on every plan; it's the entire change in one line. The +/~/- legend
here is illustrative console text; the lab shows each symbol from a real run. (~6
min)
Then: "See the same thing as a morph — config becomes plan becomes shell."
-->

---
layout: two-cols-code
heading: 'config → plan → shell'
---

````md magic-move
```hcl
# The config: desired state.
resource "random_pet" "release" {
  length = 2
}

resource "local_file" "manifest" {
  filename = "build/manifest.txt"
  content  = "release = ${random_pet.release.id}\n"
}
```

```console
# tofu plan: the diff, as a preview.
  + random_pet.release
      + id     = (known after apply)
      + length = 2

  + local_file.manifest
      + content  = (known after apply)
      + filename = "build/manifest.txt"

Plan: 2 to add, 0 to change, 0 to destroy.
```

```console
# tofu apply: converge, in dependency order.
random_pet.release:  Creating...
random_pet.release:  Creation complete [id=firm-jackal]
local_file.manifest: Creating...
local_file.manifest: Creation complete

Apply complete! Resources: 2 added.
```
````

::right::

<div class="mt-4">
  <KwCard heading="config → plan" kind="resource" variant="ok">
    <strong>What you write</strong> becomes a <strong>preview</strong>. The pet's
    <code>id</code> is <code>known after apply</code>, so the manifest that
    references it is too.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="plan → shell" variant="ok">
    <strong>apply executes the plan</strong> — pet first (the manifest needs its
    <code>id</code>), then the file. The graph, not the file, sets the order.
  </KwCard>
  </div>
</div>

<!--
Say: The same lifecycle as a morph, config to plan to shell. Start with the config
— desired state, a random_pet and a local_file that references it. Morph to the
plan: the same two resources as a preview, with the pet's id known-after-apply, so
the manifest's content is too. Morph to the shell: apply executes it, and notice the
ORDER — the pet is created first because the manifest needs its id, then the file.
You wrote no ordering; the reference created the edge and the graph sequenced it.
This is the lab's config; the slide HCL is illustrative and the lab file is the
source of truth. (~5 min)
Then: "Let's light that same pipeline up, stage by stage."
-->

---
clicks: 4
---

<span class="kw-kicker">The workflow, click by click</span>

# config → plan → apply → state

<PlanApplyFlow :step="$clicks" class="mt-10" />

<div v-click="4" class="mt-8 kw-muted text-sm text-center">

Each click lights the next stage: your **config** feeds a **plan** (the diff), the
plan drives **apply** (convergence), and apply records the result in **state** —
the memory that makes the *next* plan a diff instead of a fresh create.

</div>

<!--
Say: The whole workflow as one pipeline, four clicks. Config is what you write.
Plan is the diff OpenTofu computes from config versus state. Apply executes that
diff and converges reality. State is what apply records — and that last stage is the
one to stress: state is the memory that lets the NEXT plan be a diff against reality
instead of a from-scratch create. No state, no idempotency, no drift detection.
That's the thread into the whole next section. (~2 min)
Then: "State also encodes order — through the dependency graph."
-->

---

<span class="kw-kicker">Order for free</span>

# The dependency graph

<div class="kw-cols-2 mt-4">
  <KwCard heading="Built from references" kind="resource" variant="ok">
    <code>manifest</code> reads <code>random_pet.release.id</code>; <code>summary</code>
    reads <code>manifest.content</code>. Each reference is an <strong>edge</strong>.
  </KwCard>
  <KwCard heading="Ordered, both ways" variant="ok">
    <strong>Create:</strong> <code>release → manifest → summary</code>.
    <strong>Destroy:</strong> the exact <strong>reverse</strong> — dependents first.
  </KwCard>
</div>

<div v-click class="mt-6 space-y-2">
  <div class="flex items-center gap-3">
    <KwChip variant="ok">release</KwChip><span>→</span>
    <KwChip variant="ok">manifest</KwChip><span>→</span>
    <KwChip variant="ok">summary</KwChip>
    <span class="kw-muted text-sm">— create order (file order is irrelevant)</span>
  </div>
</div>

<div v-click class="mt-5 kw-muted text-sm">

Make two resources reference **each other** and the graph has a loop — OpenTofu
refuses with `Error: Cycle: …`. The graph must be **acyclic**. You break→fix
exactly this in the lab.

</div>

<!--
Say: OpenTofu never asks you to declare order — it derives it from references.
manifest reads the pet's id, summary reads the manifest's content; each reference is
an edge in a graph. Click: create runs release, then manifest, then summary, and the
order the blocks appear in the file is irrelevant — only the edges matter. destroy
runs the exact reverse, dependents before dependencies, so nothing is deleted out
from under something that needs it. Final click: if two resources reference each
other the graph has a cycle, and OpenTofu refuses with Error: Cycle — the graph must
be acyclic. That's the break-fix you do in the lab. (~4 min)
Then: "One more property falls out of state and the graph: idempotency."
-->

---
layout: statement
kicker: 'The defining property'
---

Run `apply` once or a hundred times — the result is the same.

**Idempotency:** the outcome depends on the *desired state*, not on how many
times you run. A second `apply` with no config change is a **no-op**.

<!--
Say: Land idempotency as the property that separates IaC from scripts. Because
apply converges to desired state and records it in state, running it again with no
change does nothing — zero added, zero changed, zero destroyed. The outcome depends
on what you declared, not on how many times you ran. A shell script re-runs its
steps blindly and can double-create or drift; apply just confirms reality already
matches and stops. In the lab you'll apply twice and watch the second run report No
changes. (~2 min)
Then: "Now run the whole loop yourself — Lab 03."
-->

---
layout: lab
lab: labs/day-1/03-core-workflow.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 03 — the core workflow

Run the **full lifecycle** — `init` (and read the lock file), `plan` (read the
`+`/`~`/`-` symbols), `apply` (watch the dependency ordering), a second `apply`
(prove idempotency), and `destroy`. Then **break it**: reference two resources at
each other, read the real `Error: Cycle:`, and fix the graph.

Every task and question has a `<details>` spoiler; panic reset is `tofu destroy`
plus `rm`.

<!--
Say: Set up the lab and its payoff. You run the entire lifecycle against a small
three-resource config: init and inspect the lock file, plan and read the symbols,
apply and watch the pet-then-manifest-then-summary ordering, apply again to see the
no-op, and destroy in reverse. The break-fix is the dependency cycle: point two
files at each other's content, watch tofu refuse with Error: Cycle naming both
resources, then break the loop and watch plan go green. Every task and question has
a spoiler; panic reset is tofu destroy plus rm — nothing cloud, nothing to leak.
(~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: The core workflow — recap
story: 'init, plan, apply, destroy — and the plan is a diff the dependency graph orders for you.'
next: 'Next: State'
---

- **Four commands:** `init` (providers + the committed `.terraform.lock.hcl`),
  `plan` (preview the diff), `apply` (converge), `destroy` (reverse teardown).
- **Read the plan:** `+` create, `~` update, `-` destroy (and `-/+` replace);
  `(known after apply)`; the `Plan: N to add / change / destroy` summary line.
- The **dependency graph** — built from references, not file order — sets create
  order and reverses it for destroy. A **cycle** fails with `Error: Cycle: …`.
- **Idempotency:** a second `apply` with no change is a **no-op** — the outcome
  depends on desired state, not run count.
- `apply` records the result in **state** — the memory the next plan diffs
  against. That's exactly where S04 goes next.

<!--
Say: Pull the threads together. Four commands: init installs providers and writes
the committed lock file; plan previews the diff; apply converges; destroy tears down
in reverse. Reading a plan is the core skill — plus create, tilde update, minus
destroy, minus-slash-plus replace, known-after-apply, and the summary line you read
first. The dependency graph, built from references and not file order, sets create
order and reverses it for destroy, and a cycle fails with Error: Cycle. Idempotency
means a no-op second apply. And apply records everything in state — the memory the
next plan diffs against. (~2 min)
Then: transition into S04 — State.
-->
