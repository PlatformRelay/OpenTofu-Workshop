---
layout: section-cover
image: /covers/section-09-the-tidy-worksite.png
day: Day 1
section: '09'
tier: recommended
---

# Best practices

You can build a config. Now learn to **evolve** one without a violent plan. How you
fan resources out (`count` vs `for_each`), the `dynamic` blocks that fan out one
level deeper, the `lifecycle` levers that tame replacement, and the refactoring
blocks — `moved`, `removed`, `import` — that change your code without rebuilding
the world.

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

<span class="kw-kicker">refactoring blocks</span>

# Change your code without rebuilding the world

<div class="kw-cols-3 mt-4">
  <KwCard heading="moved {}" kind="state" variant="ok">
    A <strong>state rename</strong>. Re-keying <code>count</code>→<code>for_each</code>
    or plainly renaming a resource plans <code>0 to add, 0 change, 0 destroy</code>
    — every instance <em>has moved to</em> its new address.
  </KwCard>
  <KwCard heading="removed {}" kind="state" variant="warn">
    Stop managing a resource but <strong>keep the object</strong> — a dedicated
    <strong><code>forget</code></strong> plan action, the reviewable successor to
    <code>tofu state rm</code>.
  </KwCard>
  <KwCard heading="import {}" kind="state" variant="accent">
    Bring pre-existing infra <strong>under management</strong>. Config-driven and,
    since <strong>1.7</strong>, <code>for_each</code>-loopable for bulk adoption.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

All three let code and state disagree **on purpose**, then reconcile without
touching real infrastructure — and all three live **in code**: reviewed in the
same diff as the config change they accompany, not typed into a console. The
next three slides run `moved` and `removed` against the lab's real files;
`import` stays conceptual here and gets its own hands-on unit.

</div>

<!--
Say: These three blocks let your code and your state disagree on purpose, then reconcile
without rebuilding. A moved block declares that an old address is the same object as a
new one — it covers the count-to-for-each migration AND the everyday plain rename, both
planning zero-zero-zero. A removed block drops a resource from state while keeping the
real object alive — it gets its own plan action, "forget", and it's the reviewable,
version-controlled successor to the imperative tofu state rm. An import block adopts an
object that already exists into state; since 1.7 it takes a for_each, so you can
bulk-import a whole fleet declaratively. The click lands the common property: all three
live in code, so state surgery travels in the same reviewed diff as the config edit —
that's the entire advance over console commands. (~2 min)
Then: "Start with moved, on the exact file the lab refactors."
-->

---
layout: two-cols-code
heading: moved — a rename is a state edit, not a rebuild
---

<!-- source: labs/day-1/09-best-practices/rename.tf -->
```hcl
# Companion artifact: release notes rendered beside the manifests.
# This resource was BORN as local_file.notes; the Step 11 refactor
# renamed the ADDRESS. Nothing about the real file changed — which is
# exactly why the rename must be a state edit, not a rebuild.
resource "local_file" "release_notes" {
  filename = "${path.module}/out/RELEASE.md"
  content  = "# Release: checkout, payments, search\n"
}

# moved: a plain RENAME — the smallest state surgery there is. Without
# this block the rename plans 1 to add, 1 to destroy (a new address is
# a new resource); with it, "has moved to" and a 0/0/0 no-op. Applied
# moved blocks are inert history: keep them as the paper trail.
moved {
  from = local_file.notes
  to   = local_file.release_notes
}
```

::right::

<div class="mt-2">
  <KwCard heading="address = identity" kind="state" variant="danger">
    Rename the block and OpenTofu sees <code>notes</code> <strong>gone</strong> and
    <code>release_notes</code> <strong>born</strong> — destroy one, create the
    other, for a file that never changed.
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="moved re-binds it" kind="state" variant="ok">
    <code>from</code>/<code>to</code> declare "same object, new address" — the
    plan drops to a pure state edit, <code>id</code> unchanged.
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="inert history" kind="state" variant="accent">
    An applied <code>moved</code> block matches nothing in state and no-ops
    forever — <strong>leave it in</strong> as the reviewable record of the
    rename.
  </KwCard>
  </div>
</div>

<!--
Say: This fence IS the tracked lab file, byte-checked in CI — the end state of the
rename you'll perform yourself. The resource was born as local_file.notes and now lives
at local_file.release_notes; the moved block underneath is what made that transition
safe. Walk the clicks. First, why a rename is dangerous at all: the address is the
identity, so renaming the block makes OpenTofu see one resource vanish and a brand-new
one appear — destroy plus create for a file whose path and content never changed. On a
local file that's churn; on a database it's an outage. Second: moved re-binds the
address to the existing object — from and to, nothing else — and the plan collapses to
a pure state edit with the id provably unchanged. Third: once applied, a moved block is
inert — its from-address matches nothing — so you leave it in the file as history; the
next reader learns the resource used to be called notes. Same verb as the
count-to-for-each migration you saw earlier, at its smallest scale. (~3 min)
Then: "Here are those two plans side by side, verbatim."
-->

---
layout: two-cols-code
heading: The rename, twice — without moved, then with
---

```console
$ tofu plan   # rename only — no moved block
...
  # local_file.notes will be destroyed
  # (because local_file.notes is not in configuration)
...
  # local_file.release_notes will be created
...
Plan: 1 to add, 0 to change, 1 to destroy.
```

```console
$ tofu plan   # same rename + moved block
  # local_file.notes has moved to local_file.release_notes
    resource "local_file" "release_notes" {
        id  = "8b2a534a4b1a8f4c5e7dfbc2fe70ce23bc58dfcf"
        # (10 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

::right::

<div class="mt-2">
  <KwCard heading="the tell" kind="state" variant="danger">
    "<em>is not in configuration</em>" on a resource you merely
    <strong>renamed</strong> — OpenTofu lost the thread of identity, not the
    resource.
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="has moved to" kind="state" variant="ok">
    One line replaces the destroy/create pair, and the <code>id</code> carries
    over — <strong>same object</strong>, new address, nothing touched on disk.
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="read the tally" kind="state" variant="accent">
    <code>1 to add, 1 to destroy</code> on a pure rename is a plan to
    <strong>stop and fix</strong>, not to approve — the same reflex as
    <code>forces replacement</code>.
  </KwCard>
  </div>
</div>

<!--
Say: Both plans are captured verbatim from the lab. Top: the rename without help. The
tell is the parenthetical — "because local_file.notes is not in configuration" — on a
resource you only renamed; OpenTofu isn't wrong, it just has no way to know the two
addresses are one object, so it plans a real destroy and a real create. Bottom: the
identical rename with the moved block — a single "has moved to" line, the id carried
over unchanged, and a zero-zero-zero tally. Click three generalises the reflex from the
plan-reading slide coming up: an add/destroy pair on a change you believe is cosmetic is
a stop signal; renames should plan as moves, and when they don't, you're about to
rebuild something for no reason. In the lab you write the moved block yourself and watch
the plan flip. (~3 min)
Then: "The second verb: retiring a resource whose artifact must survive."
-->

---
layout: two-cols-code
heading: removed — retire from state, keep the artifact
---

<!-- source: labs/day-1/09-best-practices/retire.tf -->
```hcl
# Retirement paper trail (Step 12): out/build-info.env used to be
# managed here as local_file.build_info. The resource block is deleted;
# this removed block hands the file over — OpenTofu FORGETS the object
# without destroying it. Like moved, an applied removed block is inert
# history and safe to keep.
removed {
  from = local_file.build_info

  # Say the intent out loud. destroy = false means "forget, don't
  # destroy". Omitting the lifecycle block still forgets — but with a
  # warning — and destroy = true flips this same block into a real
  # destroy of the artifact.
  lifecycle {
    destroy = false
  }
}
```

```console
$ tofu plan
  # local_file.build_info will be removed from the OpenTofu state but will not be destroyed
...
Plan: 0 to add, 0 to change, 0 to destroy, 1 to forget.
```

::right::

<div class="mt-2">
  <KwCard heading=". forget — its own verb" kind="state" variant="ok">
    Not a destroy: the plan grows a <strong>fourth tally column</strong>,
    <code>1 to forget</code>, and the apply reports
    <strong><code>1 forgotten</code></strong> — the artifact stays on disk.
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="one boolean, two fates" kind="state" variant="danger">
    <code>destroy = true</code> flips the <strong>same block</strong> into a real
    destroy; omit <code>lifecycle</code> and OpenTofu forgets by default but
    <strong>warns</strong> — write the decision down.
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="vs tofu state rm" kind="state" variant="warn">
    <code>state rm</code> is instant, unreviewed, and does <strong>half the
    job</strong> (config still declares the resource). <code>removed</code> ships
    config edit + state edit in <strong>one planned diff</strong>.
  </KwCard>
  </div>
</div>

<!--
Say: Again the fence is the tracked lab file — and note what it does NOT contain: the
resource block is gone; the removed block stands where it stood. Deleting code alone
means "destroy the object" — the lab makes you feel that plan first. removed replaces
that meaning with "stop tracking it": the plan grows a genuinely separate action symbol,
dot-forget, its own column in the tally — zero to destroy, one to forget — and the apply
summary reads "1 forgotten" with the file provably intact. Click two is the edge the lab
also runs: the lifecycle boolean is the whole decision. destroy equals true turns this
identical block into a real destroy; leaving lifecycle out still forgets but draws a
warning, because OpenTofu wants the fate written down, not defaulted. Click three is the
contrast with the imperative tool from the state lab: state rm forgets instantly but is
unreviewed and leaves the config edit as a separate step you must remember — removed
puts both edits in one diff that plans before it acts. One more real detail: the apply
warns that re-managing the file later means import — the third verb. (~4 min)
Then: "moved and removed are the runnable core; dynamic blocks are the next DRY tool."
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
gets the iterator's value. This cloud shape is what you'll meet in the wild; you don't
need a cloud to write one, though. (~3 min)
Then: "Here's the exact same shape in the lab project — the file you'll author yourself."
-->

---
layout: two-cols-code
heading: dynamic in the lab project — the file you will write
---

<!-- source: labs/day-1/09-best-practices/bundle.tf -->
```hcl
# The deploy artifact: ONE zip holding every service's manifest.
# (hashicorp/archive is declared in main.tf — a module may carry
# only one required_providers block.)
# "source" is a repeated NESTED BLOCK inside this data source —
# exactly the shape dynamic blocks exist to generate.
data "archive_file" "bundle" {
  type        = "zip"
  output_path = "${path.module}/out/bundle.zip"

  # One source{} per service. The iterator is named after the
  # LABEL: source.key / source.value, not each.key / each.value.
  dynamic "source" {
    for_each = var.services
    content {
      filename = "${source.key}.env"
      content  = "REPLICAS=${source.value.replicas}\n"
    }
  }
}

output "bundle_sha256" {
  description = "Bundle checksum — changes with any manifest."
  value       = data.archive_file.bundle.output_sha256
}
```

::right::

<div class="mt-2">
  <KwCard heading='dynamic "source"' kind="resource" variant="accent">
    The <strong>label names the nested block type</strong> to generate —
    here <code>archive_file</code>'s repeated <code>source {}</code> entry.
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="source.key / source.value" kind="resource" variant="warn">
    The iterator is <strong>named after the label</strong> — writing
    <code>each.*</code> here is the classic first error (the lab makes you
    hit it).
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="one wired truth" kind="state" variant="ok">
    Adding a service to <code>var.services</code> updates the manifest fleet
    <strong>and</strong> this bundle in the same plan — the checksum output
    proves it.
  </KwCard>
  </div>
</div>

<!--
Say: The same dynamic shape, pure-local: the lab project zips one .env entry per service
into a deploy bundle, and the repeated source blocks inside archive_file are generated by
a dynamic block over the same var.services map that fans out the manifest resources. This
fence IS the tracked lab file, byte-checked in CI — and in the lab you'll re-derive it by
hand. Walk the three clicks: the label names the nested block type to synthesise; the
iterator is named after that label, source.key and source.value, which is where everyone
first writes each-dot and gets a real error; and the payoff — one map entry added means
the manifest fleet AND the bundle update in one plan, with the checksum output as the
visible proof. In the lab you'll also regress it to hand-copied blocks and watch the
copy-paste form silently forget a new service. (~4 min)
Then: "That iterator error is worth seeing in full — plus the judgement call on when
dynamic is even a good idea."
-->

---
layout: two-cols-code
heading: The classic dynamic error — and the judgement call
---

```console
$ tofu plan
╷
│ Error: Reference to "each" in context without for_each
│
│   on bundle.tf line 9, in data "archive_file" "bundle":
│    9:       filename = "${each.key}.env"
│
│ The "each" object can be used only in "module" or "resource" blocks, and
│ only when the "for_each" argument is set.
╵
```

```hcl
# the fix: the iterator is the LABEL (or an explicit override)
dynamic "source" {
  for_each = var.services          # iterator: source.*
  iterator = svc                   # optional: now svc.*
}
```

::right::

<div class="mt-2">
  <KwCard heading="sensible" kind="resource" variant="ok">
    The collection is an <strong>input</strong> — its length changes without
    editing this file (<code>var.services</code>, ingress rules from a
    variable).
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="obfuscation" kind="resource" variant="danger">
    A <code>dynamic</code> around a <strong>single fixed block</strong>, a
    small set you could enumerate in review, or
    <code>dynamic</code>-inside-<code>dynamic</code>.
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="the tiebreak" kind="state" variant="accent">
    Literal blocks planned <strong><code>No changes</code></strong> against the
    dynamic form — it's pure expansion sugar, so use it only when it
    <strong>removes a second copy of the truth</strong>.
  </KwCard>
  </div>
</div>

<!--
Say: Two things to lock in before the lab. First the error text on the left, verbatim
from a real run: write each-dot inside a dynamic block and OpenTofu tells you "each" only
exists on module and resource blocks — inside dynamic, the iterator is named after the
label, or after an explicit iterator argument if you set one. You will trigger and fix
this yourself. Second, the judgement call on the right: dynamic is sensible when the
collection is an input whose length changes without editing the file; it's obfuscation
around a single fixed block or a small reviewable set, and nested dynamics are a
maintenance trap. The tiebreak is a fact the lab proves: swapping literal blocks for the
dynamic form plans as No changes — dynamic is authoring-time sugar, so it must earn its
place by deleting a second copy of the truth, like the retyped replica counts in the
copy-paste bundle. (~3 min)
Then: "One more fan-out rule that bites at plan time — the width has to be knowable."
-->

---
layout: two-cols-code
heading: Fan-out width must be known at plan time
---

```console
$ tofu plan
╷
│ Error: Invalid count argument
│
│   on receipts.tf line 11, in resource "local_file" "receipt":
│   11:   count    = length(local_file.audit.content_sha256)
│
│ The "count" value depends on resource attributes that cannot be determined
│ until apply, so OpenTofu cannot predict how many instances will be created.
│
│ To work around this, use the planning option -exclude=local_file.receipt to
│ first apply without this object, and then apply normally to converge.
╵
```

::right::

<div class="mt-2">
  <KwCard heading="why it's refused" kind="state" variant="danger">
    A plan is a <strong>complete promise</strong>: a width that is
    <em>(known after apply)</em> can't be enumerated. Same rule for
    <code>for_each</code> <strong>keys</strong>.
  </KwCard>
  <div v-click class="mt-3">
  <KwCard heading="workaround: -exclude" kind="resource" variant="warn">
    OpenTofu itself suggests <code>-exclude</code> (<strong>1.9+</strong>,
    OpenTofu-only — S10) to plan around the resource in <strong>two
    passes</strong>.
  </KwCard>
  </div>
  <div v-click class="mt-3">
  <KwCard heading="fix: width from config" kind="resource" variant="ok">
    Derive the width from <strong>configuration</strong>
    (<code>length(var.services)</code>) — always known at plan, one clean
    pass.
  </KwCard>
  </div>
</div>

<!--
Say: The last fan-out rule, again with the real error text: derive count — or for_each
keys — from another resource's computed attribute and OpenTofu refuses to plan, because a
plan must enumerate every instance up front and "known after apply" can't be enumerated.
The real-world shape is count equals length of some module's output list. Click one: why
it's refused — a plan is a complete promise. Click two: the error itself suggests
-exclude, an OpenTofu-only planning option from 1.9 that S10 covers, which gets you
through in two passes. Click three: the actual fix is structural — derive the width from
configuration, which is always known at plan time. The lab reproduces this trap with a
two-resource scratch file, runs the workaround, and applies the fix. (~3 min)
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
clicks: 5
---

<span class="kw-kicker">Back to the reconcile</span>

# Every plan diff assumes three things

<StateReconcile :step="$clicks" class="mt-10" />

<div v-click="5" class="mt-8 kw-muted text-sm text-center">

The same **desired → state → actual** model from S04 — a plan diff is
**reconcile** output. Read replacement signals knowing which comparison failed.

</div>

<!--
Say: Before reading a diff line by line, re-ground the reconcile model from S04.
Click through: desired, state, actual, refresh catching drift, reconcile as the
plan. Every -/+ and "must be replaced" in the next slide is this pipeline
surfacing a mismatch — config change or drift — not random noise. (~2 min)
Then: "Now read one plan carefully — the replacement signals to never miss."
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
this plan — you'll trigger it, read it line by line, and revert. Read the diff as plain
text — the reconcile model from the previous slide is what every line assumes. (~4 min)
Then: "Now go make count-to-for-each churn, then fix it with moved — Lab 09."
-->

---
layout: lab
lab: labs/day-1/09-best-practices.md
duration: 60 min
env: 'mock ✓ (no docker)'
---

# Lab 09 — count vs for_each, dynamic blocks, and refactor without replacement

Start from a `count` fan-out and remove a middle element to watch it churn later
instances (`2 to destroy` for removing **one**). Refactor to `for_each` with `moved`
blocks and prove the migration is a state-only no-op (`0 to add, 0 change, 0
destroy`). Then **write a `dynamic` block yourself** — regress the bundle to
copy-paste blocks, watch it *silently forget* a new service, hit the classic
`each.*` error, and fix it. Part B runs the refactoring verbs in full: replay
`tofu state rm`, plan a **plain rename** with and without `moved`
(`1 to destroy` vs `has moved to`), then retire a resource with **`removed`**
and read the new **`1 to forget`** tally — artifact intact on disk. Plus the
**break→fix** beats: a mis-keyed map, a `filename` edit that re-creates the
whole fleet, a width unknown at plan time, a dangling reference, and the one
boolean that separates *forget* from *destroy*.

Every task has a `<details>` spoiler; panic reset leaves the tree clean.

<!--
Say: Set up the lab and its payoff. You'll start where real configs start — a count
fan-out — and remove the middle service to see the plan destroy two resources for a
one-service deletion, churning an instance you never touched. Then you refactor to
for_each with three moved blocks and prove the whole migration plans as zero add, zero
change, zero destroy — a pure state rename. Then the dynamic unit: inspect the bundle,
regress it to hand-copied blocks, watch the copy-paste form silently miss a new service,
and write the dynamic block yourself — hitting the each-dot error on the way. Part B is
the refactoring unit: replay tofu state rm and see it do half the job, rename a resource
and compare the destroy/create plan against the has-moved-to no-op, then retire a
resource with removed — feeling the dangling-reference error, the plain-deletion destroy,
and the missing-lifecycle warning on the way to a "1 forgotten" apply with the file
intact. Along the way the remaining break-fixes: a mis-keyed map lookup, the one-word
filename edit that wants to rebuild all three instances with "forces replacement," and
the unknown-width count error with its -exclude workaround. No Docker, pure local
providers. Every task has a spoiler; panic reset leaves the tree clean. (~60 min,
matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Best practices — recap
story: 'Evolve a config safely: choose for_each, generate nested blocks with dynamic, refactor state with moved, and read the plan for replacement.'
next: 'Next: OpenTofu differentiators'
---

- **`count` vs `for_each`:** `count` addresses by index (a middle removal
  renumbers and rebuilds later instances); `for_each` addresses by key (removal is
  surgical). Prefer `for_each` for anything with a stable identity.
- **Refactoring blocks move state, not infra:** `moved` renames/re-keys with no
  replacement (`has moved to`, `id` unchanged — a plain rename without it plans
  destroy+create); `removed` un-manages while keeping the object (its own
  `. forget` action and `1 to forget` tally, `lifecycle { destroy = false }`
  making the fate explicit — the reviewable successor to `tofu state rm`);
  `import` adopts existing infra — `for_each`-loopable since **1.7**.
- **`dynamic` blocks** generate repeated nested blocks from a collection — the
  iterator is named after the **label** (`source.*`, not `each.*`), it's pure
  expansion sugar (the literal form plans `No changes`), and it's earned only
  when it removes a second copy of the truth — don't wrap a block that appears
  once.
- **Fan-out width must be known at plan time:** `count`/`for_each` fed a computed
  attribute fails with `Invalid count argument`; `-exclude` (1.9+) is the
  two-pass workaround, width-from-configuration is the fix.
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
without replacement — the lab proved the same rename plans destroy-plus-create without
it and a no-op with it; removed un-manages while keeping the object, with its own
forget action in the plan tally and the lifecycle boolean writing the forget-or-destroy
decision down — the reviewable successor to tofu state rm; and import adopts existing
infra, loopable since 1.7. dynamic blocks keep repeated nested blocks DRY — the
iterator is the label, the expansion is pure sugar, and it's earned only when the
collection is an input; and fan-out width must be known at plan time, with -exclude as
the two-pass workaround and width-from-configuration as the fix. lifecycle gives you
create_before_destroy, prevent_destroy, and ignore_changes for when the default
replacement behaviour is wrong. And underneath all of it: read the plan —
the replacement signals and the destroy tally are what keep an evolution calm. Call
forward: next we look at what makes OpenTofu itself distinct. (~2 min)
Then: transition into OpenTofu differentiators.
-->
