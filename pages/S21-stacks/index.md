---
layout: section-cover
image: /covers/section-21-mapping-the-districts.webp
day: Day 3
section: '21'
tier: core
---

# Stacks

## Turn directories into discoverable units of work

<!--
Say: S20 left you with a monorepo skeleton and an empty terramate list. Today those leaf directories become stacks — named, tagged, listed units Terramate can discover. Discovery is the first verb of Day 3. (~1 min)
Then: Define what a stack is in one sentence.
-->

---
layout: statement
kicker: 'Unit of work'
---

A **stack** is a directory Terramate recognises as one OpenTofu (or Terraform)
root — its own state, its own plan/apply, its own blast radius.

Discovery is not a folder walk. It is a **`stack {}` declaration**.

<!--
Say: Say it twice. A stack is a directory that is also a tofu root — own state, own run, own blast radius. Terramate does not invent stacks from directory names alone; it discovers directories that declare stack {}. That is why S20's list was empty on purpose. (~2 min)
Then: Highlight the discover phase on the Day-3 loop.
-->

---
clicks: 4
---

<span class="kw-kicker">orchestration · discover</span>

# Four phases — today is discover

<TerramateOrchestration phase="discover" :step="$clicks" class="mt-8" />

<div v-click="4" class="mt-8 kw-muted text-sm text-center">

Generate, order, and filter come in <strong>S22</strong>–<strong>S24</strong>. Tags already appear in list filters today; change-detection filtering is S24.

</div>

<!--
Say: Same four-phase loop as S20, but the accent is on discover. Generate, order, and filter stay greyed as later sections. Tags already appear in list filters today; change-detection filtering is S24. (~2 min)
Then: Show the file that makes discovery real.
-->

---
layout: two-cols-code
heading: Author `stack.tm.hcl` field by field
---

````md magic-move
```hcl
# Empty directory ≠ stack. Discovery needs this block.
stack {
}
```

```hcl
stack {
  name = "network"
}
```

```hcl
stack {
  name        = "network"
  description = "Shared network foundation"
}
```

```hcl
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
}
```

```hcl
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
  id          = "11111111-1111-1111-1111-111111111111"
}
```
````

::right::

<div class="mt-2">
  <KwCard heading="name" kind="module" variant="plain">
    Human label in lists and docs — defaults to the directory basename.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="tags" kind="validation" variant="accent">
    Selection keys for <code>terramate list --tags</code> (and later runs).
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="id" kind="state" variant="ok">
    Stable identity across renames. Prefer an explicit UUID in tracked files.
  </KwCard>
  </div>
</div>

<!--
Say: Watch the block grow. An empty stack {} is enough to be discovered — but metadata is what makes a monorepo operable. Name is the label. Description is for humans. Tags are how you filter without hard-coding paths. Id keeps identity stable when directories move. The final frame matches the lab's tracked network stack. (~4 min)
Then: Show the CLI that writes the same file.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · network stack</span>

# `stack.tm.hcl` is the contract

<!-- source: labs/day-3/21-stacks/stacks/network/stack.tm.hcl -->
```hcl {1|2-3|4|5|1-6}
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
  id          = "11111111-1111-1111-1111-111111111111"
}
```

::notes::

<CodeNote at="1" label="Block">Without <code>stack {}</code>, Terramate silently skips the directory.</CodeNote>
<CodeNote at="2" label="Labels">Name and description are for humans and reports.</CodeNote>
<CodeNote at="3" label="Tags">Filter with <code>--tags networking</code> — no path hard-coding.</CodeNote>
<CodeNote at="4" label="Id">Stable UUID — <code>terramate create --id</code> can set it.</CodeNote>
<CodeNote at="5" label="File">Lives beside <code>main.tf</code> in the OpenTofu root.</CodeNote>

<!--
Say: Point at the tracked file in the lab workdir. This is the single source of truth for the slide. Emphasise the silent-skip rule on the first note — that is today's break→fix. Tags unlock list filters without naming paths. (~3 min)
Then: Show create and list as the discover CLI.
-->

---
layout: comparison
leftHeading: Create
leftBadge: declare
rightHeading: List
rightBadge: discover
---

<span class="kw-kicker">CLI · discover</span>

# `terramate create` / `terramate list`

::left::

```bash
terramate create stacks/network \
  --name network \
  --description 'Shared network foundation' \
  --tags networking,shared \
  --id 11111111-1111-1111-1111-111111111111 \
  --no-generate
```

::right::

```console
$ terramate list
stacks/app
stacks/network

$ terramate list --tags networking
stacks/network

$ terramate list --tags app
stacks/app
```

<!--
Say: create writes stack.tm.hcl (and can import existing tofu roots with --all-terraform). --no-generate keeps S22's codegen out of today's lab. list prints every discovered stack path; --tags filters to a subset. Spoilers match terramate 0.17.x. (~3 min)
Then: Hands-on — split flat leaves into tagged stacks, then break discovery on purpose.
-->

---
layout: lab
lab: labs/day-3/21-stacks.md
duration: 30 min
env: 'mock ✓ (no docker)'
---

# Lab — declare stacks; list & filter

- Start from the flat S20 leaves → `terramate create` with tags.
- `terramate list` and `--tags` filters.
- Break→fix: remove `stack {}` → silent non-discovery → restore.

<!--
Say: Learners stay on mock — no Docker. They copy the workdir, strip stack files to feel the empty list, recreate with create + tags, filter, then deliberately break one stack and watch it vanish from list without an error. Spoilers match a real terramate run. (~30 min)
Then: Debrief — discovery is declarative metadata, not a folder convention.
-->

---
layout: recap
next: S22 · Code generation
---

<span class="kw-kicker">recap · discovery</span>

# Stacks — operating rules

- A stack is a tofu root Terramate can **discover** — only with `stack {}`.
- Metadata (`name`, `description`, `tags`, `id`) makes listing and filtering useful.
- `terramate create` writes the contract; `terramate list` proves discovery.
- Missing `stack {}` fails **silently** — the directory simply does not appear.

<p v-click class="mt-8 text-xl font-semibold">No <code>stack {}</code>, no discovery — folders alone are not enough.</p>

<!--
Say: Close on the discover contract. Directories become stacks when they declare stack {}. Tags and ids are how you operate a monorepo without path spaghetti. Next, S22 generates the duplicated backend and provider boilerplate so leaves stay DRY. (~2 min)
Then: S22 · Code generation.
-->
