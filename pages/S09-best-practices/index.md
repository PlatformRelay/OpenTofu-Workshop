---
layout: section-cover
image: /covers/section-09-the-tidy-worksite.png
day: Day 1
section: '09'
tier: recommended
---

# Best practices

You can build a config. Now learn to **evolve** one without a violent plan. How you
fan resources out (`count` vs `for_each`), the `lifecycle` levers that tame
replacement, and the refactoring blocks — `moved`, `removed`, `import` — that
change your code without rebuilding the world.

<!--
Say: Frame the section as the "day two" of a config's life. Everything so far — authoring,
typing, guarding, packaging — was about standing a config up. This section is about
changing one that already exists, safely: the difference between a refactor that plans
as a no-op and one that quietly destroys and recreates your fleet. Four levers do it:
choosing count versus for_each, dynamic blocks to keep repetition DRY, the lifecycle
meta-arguments, and the refactoring blocks that move state without touching real infra.
It's tier recommended — high-value practice, not a core primitive. (~1 min)
Then: "Start with the one decision that most often causes an accidental rebuild — count
versus for_each."
-->

---
layout: statement
kicker: 'The core decision'
---

`count` addresses instances by **index**; `for_each` by **key**.

That one difference decides whether removing a resource is **surgical** or
**renumbers everything after it** into a destroy+recreate.

<!--
Say: Land the single most consequential choice in the section. Both count and for_each
fan one resource block into many instances, but they identify those instances
differently: count by numeric position, for_each by a stable key. That sounds academic
until you delete something from the middle — under count every later instance shifts
down one index, and because an instance's address is its identity, OpenTofu sees brand
new resources and rebuilds them. Under for_each the surviving keys never move. This is
the whole reason for_each is the default recommendation. (~2 min)
Then: "Here's that difference on a real plan — the trap and the fix side by side."
-->

---
layout: two-cols-code
heading: The removal trap — index shift vs stable key
---

````md magic-move
```hcl
# count: instances are addressed by INDEX. manifest[0], [1], [2].
resource "local_file" "manifest" {
  count = length(var.services)

  filename = "out/${var.services[count.index].name}.env"
  # ...
}
```

```hcl
# Remove the MIDDLE service. Every later index shifts down by one —
# manifest[1] is now a different service, manifest[2] falls out of range.
#   Plan: 1 to add, 0 to change, 2 to destroy   ← you removed ONE
```

```hcl
# for_each: instances are addressed by KEY. manifest["payments"], …
resource "local_file" "manifest" {
  for_each = var.services

  filename = "out/${each.key}.env"
  # ...
}
```

```hcl
# Remove the same middle service. Only its KEY leaves the map; the
# surviving keys never move.
#   Plan: 0 to add, 0 to change, 1 to destroy   ← surgical
```
````

::right::

<div class="mt-2">
  <KwCard heading="count → index" kind="resource" variant="danger">
    Identity is a <strong>position</strong>. Delete element 1 and element 2
    becomes element 1 — an immutable resource is <strong>replaced</strong>.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="for_each → key" kind="resource" variant="ok">
    Identity is a <strong>key</strong>. Delete key <code>payments</code> and
    <code>checkout</code>/<code>search</code> aren't even in the plan.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="Rule of thumb" kind="state" variant="accent">
    <code>count</code> for a simple <strong>N-of-identical</strong> toggle;
    <code>for_each</code> whenever instances have a <strong>stable identity</strong>.
  </KwCard>
  </div>
</div>

<!--
Say: This is the heart of the section, and the lab proves every number on it. Move one:
a count fan-out, addressed by index. Move two: remove the middle service — you deleted
one, but the plan is one-to-add, two-to-destroy, because index 1 is recomputed as a
different service and forced to replace, and index 2 falls out of range and is
destroyed. Move three: the same resource with for_each, keyed by name. Move four: the
identical removal now plans as a single destroy — the surviving keys aren't touched at
all. The rule of thumb on the right: reach for count only for a plain N-of-identical
count; use for_each the moment instances have a stable identity, which is almost always.
(~4 min)
Then: "So you'll usually migrate count to for_each — but that changes every address.
Here's how to do it without a rebuild."
-->

---
layout: two-cols-code
heading: Refactor in state, not in the world — moved / removed / import
---

```hcl
# moved: an old address IS this new one. Rename or re-key WITHOUT replacement.
moved {
  from = local_file.manifest[0]         # was count-indexed
  to   = local_file.manifest["checkout"] # now for_each-keyed
}

# removed: drop a resource from STATE without destroying the real object.
removed {
  from = local_file.legacy
  lifecycle { destroy = false }
}

# import: adopt an EXISTING object into state. Loopable (for_each) since 1.7.
import {
  for_each = var.adopt
  to       = local_file.manifest[each.key]
  id       = each.value
}
```

::right::

<div class="mt-2">
  <KwCard heading="moved {}" kind="state" variant="ok">
    A <strong>state rename</strong>. The <code>count</code>→<code>for_each</code>
    migration plans <code>0 to add, 0 change, 0 destroy</code> — every instance
    <em>has moved to</em> its new address.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="removed {}" kind="state" variant="warn">
    Stop managing a resource but <strong>keep the object</strong>
    (<code>destroy = false</code>) — the reviewable successor to
    <code>tofu state rm</code>.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="import {}" kind="state" variant="accent">
    Bring pre-existing infra <strong>under management</strong>. Config-driven and,
    since <strong>1.7</strong>, <code>for_each</code>-loopable for bulk adoption.
  </KwCard>
  </div>
</div>

<!--
Say: These three blocks let your code and your state disagree on purpose, then reconcile
without rebuilding. A moved block declares that an old address is the same object as a
new one — it's what makes the count-to-for-each migration a pure state rename, planning
zero add, zero change, zero destroy, with every instance reported as "has moved to." A
removed block drops a resource from state while keeping the real object alive via
destroy equals false — the reviewable, version-controlled successor to the imperative
tofu state rm. And an import block adopts an object that already exists into state; since
1.7 it takes a for_each, so you can bulk-import a whole fleet declaratively instead of
one CLI call at a time. All three live in code, so they're reviewed and repeatable. (~4 min)
Then: "moved and count-vs-for-each are the runnable core; dynamic blocks are the next
DRY tool."
-->

---
layout: code-annotated
heading: dynamic blocks — generate repeated nested blocks
---

```hcl {none|1-2|4|5-8|all}
variable "ingress_rules" {
  type = list(object({ port = number, cidr = string }))
}

resource "aws_security_group" "web" {
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port = ingress.value.port
      to_port   = ingress.value.port
      cidr_blocks = [ingress.value.cidr]
    }
  }
}
```

::notes::

<CodeNote at="1" label="the input" variant="ok">
  A variable-length list drives however many nested blocks you need — no
  hand-copying identical <code>ingress { }</code> stanzas.
</CodeNote>

<CodeNote at="2" label='dynamic "ingress"'>
  Names the <strong>nested block</strong> to synthesise — here a security-group
  <code>ingress</code> rule. The label is the block type, not a resource.
</CodeNote>

<CodeNote at="3" label="for_each + content" variant="warn">
  Iterate the input; each <code>content { }</code> becomes one generated block,
  reading the iterator via <code>ingress.value</code>.
</CodeNote>

<!--
Say: dynamic blocks are for_each one level deeper — inside a resource. Some resources
take a variable number of repeated NESTED blocks: security-group ingress rules, IAM
policy statements, load-balancer listeners. Hand-writing five near-identical ingress
stanzas is exactly the copy-paste a convention should kill. A dynamic block takes a
for_each and a content template and generates one nested block per element. Read it as:
name the nested block type in the dynamic label, feed it a collection, and each content
gets the iterator's value. Use it to keep repeated blocks DRY — but don't reach for it
when the block appears once; dynamic on a single fixed block just hurts readability. This
is a slide concept: it needs a real cloud provider, so the no-Docker lab sticks to
local. (~3 min)
Then: "Last set of levers — lifecycle, for when you need to override the default
replacement behaviour."
-->

---

<span class="kw-kicker">lifecycle meta-arguments</span>

# Override how a resource is replaced

<div class="kw-cols-3 mt-4">
  <KwCard heading="create_before_destroy" kind="resource" variant="ok">
    On replacement, <strong>build the new before destroying the old</strong> — no
    outage gap. The go-to for zero-downtime swaps.
  </KwCard>
  <KwCard heading="prevent_destroy" kind="resource" variant="danger">
    A <strong>hard stop</strong>: any plan that would destroy this resource
    <strong>errors</strong>. A guardrail for a database or a state bucket.
  </KwCard>
  <KwCard heading="ignore_changes" kind="resource" variant="warn">
    Stop fighting drift on specific attributes — OpenTofu <strong>won't plan a
    change</strong> for fields an external system owns.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

`lifecycle` is a **`meta`-block** — it takes literals, not references. Reach for it
deliberately: `prevent_destroy` on the thing that must never be recreated,
`create_before_destroy` when a replacement can't have a gap, `ignore_changes` for a
field a controller or autoscaler mutates behind you.

</div>

<!--
Say: The lifecycle block is your override for OpenTofu's default replacement behaviour,
and it has three levers worth knowing cold. create_before_destroy flips the order:
normally OpenTofu destroys then creates on a replacement, which opens an outage gap;
this builds the replacement first, so it's the default for zero-downtime swaps. prevent
underscore destroy is a hard stop — any plan that would destroy this resource errors
out, so you put it on the database or the state bucket that must never be recreated.
ignore_changes tells OpenTofu to stop planning changes on specific attributes that an
external system owns — an autoscaler's desired count, a controller-managed tag — so you
stop fighting perpetual drift. The click makes the one gotcha explicit: lifecycle is a
meta-block that takes literal values, not references. (~4 min)
Then: "Those levers all show up in one place you read every run — the plan. Let's read
one carefully."
-->

---
layout: two-cols-code
heading: Read the plan — the replacement signals to never miss
---

```diff
# The signal that a change is destructive — read it every run:

  # local_file.manifest["checkout"] must be replaced
-/+ resource "local_file" "manifest" {
      ~ filename = "./out/checkout.env" -> "./out/checkout.conf" # forces replacement
    }

# ...and the whole-fleet tally at the bottom:
  Plan: 3 to add, 0 to change, 3 to destroy
```

::right::

<div class="mt-2">
  <KwCard heading="-/+ and 'must be replaced'" kind="resource" variant="danger">
    <strong>Destroy then create.</strong> The resource can't be edited in place —
    an immutable field changed.
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="# forces replacement" kind="resource" variant="warn">
    Points at the <strong>exact attribute</strong> to blame. A one-word
    <code>filename</code> edit here rebuilds every instance.
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="the bottom tally" kind="state" variant="accent">
    <code>N to destroy</code> on a change you thought was cosmetic is your
    cue to <strong>stop</strong> — never <code>-auto-approve</code> a surprise.
  </KwCard>
  </div>
</div>

<!--
Say: Every lever in this section surfaces in one artefact you already read every run —
the plan — so make reading it a reflex. Walk the click sequence. First, the -/+ prefix
and the "must be replaced" header mean destroy-then-create: some immutable field changed
and OpenTofu can't edit in place. Second click: the "# forces replacement" annotation
names the exact attribute to blame — here a one-word filename change from .env to .conf.
Third click: the bottom-line tally. Seeing "three to destroy" on what you thought was a
cosmetic edit is the moment to stop, not to auto-approve. The lab's break-fix is exactly
this plan — you'll trigger it, read it line by line, and revert. This is the fallback
plan-diff view, read as plain diff, no tooling needed. (~4 min)
Then: "Now go make count-to-for-each churn, then fix it with moved — Lab 09."
-->

---
layout: lab
lab: labs/day-1/09-best-practices.md
duration: 30 min
env: 'mock ✓ (no docker)'
---

# Lab 09 — count vs for_each, and refactor without replacement

Start from a `count` fan-out and remove a middle element to watch it churn later
instances (`2 to destroy` for removing **one**). Refactor to `for_each` with `moved`
blocks and prove the migration is a state-only no-op (`0 to add, 0 change, 0
destroy`). Then **break→fix**: an innocent `filename` edit that forces the whole
fleet to re-create, caught in `plan`, then reverted.

Every task has a `<details>` spoiler; panic reset leaves the tree clean.

<!--
Say: Set up the lab and its payoff. You'll start where real configs start — a count
fan-out — and remove the middle service to see the plan destroy two resources for a
one-service deletion, churning an instance you never touched. Then you refactor to
for_each with three moved blocks and prove the whole migration plans as zero add, zero
change, zero destroy — a pure state rename. Then the headline break-fix: change one word
in a filename, watch plan want to rebuild all three instances with "forces replacement,"
and revert it. No Docker, pure local provider. Every task has a spoiler; panic reset
leaves the tree clean. (~30 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Best practices — recap
story: 'Evolve a config safely: choose for_each, refactor state with moved, and read the plan for replacement.'
next: 'Next: OpenTofu differentiators'
---

- **`count` vs `for_each`:** `count` addresses by index (a middle removal
  renumbers and rebuilds later instances); `for_each` addresses by key (removal is
  surgical). Prefer `for_each` for anything with a stable identity.
- **Refactoring blocks move state, not infra:** `moved` renames/re-keys with no
  replacement, `removed` un-manages while keeping the object, `import` adopts
  existing infra — `for_each`-loopable since **1.7**.
- **`dynamic` blocks** generate repeated nested blocks from a collection — DRY, but
  don't wrap a block that appears once.
- **`lifecycle`:** `create_before_destroy` (no gap), `prevent_destroy` (hard stop),
  `ignore_changes` (stop fighting external drift).
- **Read the plan:** `-/+` / `must be replaced` / `# forces replacement` and the
  bottom `N to destroy` tally are your stop signals — never `-auto-approve` a
  surprise.

<!--
Say: Pull the threads together. The core decision is count versus for_each: count
addresses by index so a middle removal renumbers and rebuilds later instances, while
for_each addresses by key so removal is surgical — prefer for_each for anything with a
stable identity. The refactoring blocks let code and state diverge safely: moved renames
without replacement, removed un-manages while keeping the object, and import adopts
existing infra, loopable since 1.7. dynamic blocks keep repeated nested blocks DRY, and
lifecycle gives you create_before_destroy, prevent_destroy, and ignore_changes for when
the default replacement behaviour is wrong. And underneath all of it: read the plan —
the replacement signals and the destroy tally are what keep an evolution calm. Call
forward: next we look at what makes OpenTofu itself distinct. (~2 min)
Then: transition into OpenTofu differentiators.
-->
