---
layout: section-cover
image: /covers/placeholder-section.svg
day: Day 1
section: '02'
tier: core
---

# HCL & building blocks

Every OpenTofu config is the same small grammar — **blocks** of **arguments**
whose values are **expressions** — assembled from a handful of block types. Learn
the seven, and you can read and write any config you meet.

<!--
Say: Frame S02. HCL looks like a lot until you see it's one tiny grammar — blocks,
arguments, expressions — plus a fixed, small set of block types. By the end of this
section you'll recognise and be able to write all seven core blocks: resource,
variable, output, provider, data, locals, and module. That's the whole vocabulary
of every config you'll ever read. (~1 min)
Then: "Start with the grammar itself — three concepts and you can parse any file."
-->

---

<span class="kw-kicker">The grammar</span>

# Blocks, arguments, expressions

<div class="kw-cols-3 mt-6">
  <KwCard heading="Block" variant="ok">
    A <strong>header</strong> plus a <code>{ … }</code> body:
    <code>resource "local_file" "x" { }</code>. The words after the type are
    <em>labels</em>.
  </KwCard>
  <KwCard heading="Argument" variant="ok">
    A <code>name = value</code> pair <em>inside</em> a body:
    <code>length = 2</code>. The building block of every block.
  </KwCard>
  <KwCard heading="Expression" variant="ok">
    The <strong>value side</strong>: a literal, a reference
    (<code>var.owner</code>), a function (<code>upper(…)</code>), or an
    interpolation <code>"${…}"</code>.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

That's the entire syntax. Everything else is *which* block type you reach for —
and there are only seven you need.

</div>

<!--
Say: Three concepts and you can parse any HCL. A block is a header plus a
curly-brace body; the quoted words after the type are labels — for a resource,
that's the resource type and your local name. An argument is a name-equals-value
pair inside a body. An expression is the value side: a literal, a reference like
var.owner, a function call like upper(), or a "${}" interpolation. Click: that is
the whole grammar. The only thing left to learn is which block type to use — and
there are just seven. (~3 min)
Then: "Here are the seven block types, each with one job."
-->

---

<span class="kw-kicker">The vocabulary</span>

# The seven core block types

<div class="kw-cols-3 mt-4">
  <KwCard heading="resource" kind="resource" variant="ok">
    Something OpenTofu <strong>creates, updates, destroys</strong>. The only block
    that changes real objects.
  </KwCard>
  <KwCard heading="variable" kind="variable" variant="ok">
    A typed <strong>input</strong>. Override via <code>-var</code>, a
    <code>*.tfvars</code> file, or an env var.
  </KwCard>
  <KwCard heading="output" kind="output" variant="ok">
    A value <strong>surfaced</strong> after apply and consumable by other configs.
  </KwCard>
  <KwCard heading="provider" kind="provider" variant="ok">
    Configures a <strong>plugin</strong> (a cloud, <code>local</code>,
    <code>random</code>, …).
  </KwCard>
  <KwCard heading="data" kind="data" variant="ok">
    <strong>Reads</strong> something that already exists — never manages it.
  </KwCard>
  <KwCard heading="locals" kind="locals" variant="ok">
    Named <strong>expressions</strong> computed once and reused.
  </KwCard>
</div>

<div class="mt-4">
  <KwCard heading="module" kind="module" variant="ok">
    <strong>Calls reusable config</strong>: pass inputs, read outputs back. This is
    how you compose. (Plus the top-level <code>terraform {}</code> settings block —
    versions &amp; provider requirements.)
  </KwCard>
</div>

<!--
Say: The seven, each with one job. Resource is the only one that creates, updates,
or destroys real objects — everything else supports it. Variable is a typed input;
output is a surfaced value; provider configures a plugin; data reads something that
already exists without managing it; locals are computed named expressions; module
calls reusable config so you can compose. There's also the top-level terraform {}
settings block that pins versions and provider requirements. Keep saying: only
resource (and resources inside modules) actually change the world. (~4 min)
Then: "Now watch a real config grow one block at a time."
-->

---
layout: two-cols-code
heading: A config, block by block
---

````md magic-move
```hcl
# provider — declare the plugin this config uses.
provider "local" {}
```

```hcl
provider "local" {}

# resource — the only block that creates real objects.
resource "local_file" "summary" {
  filename = "build/summary.txt"
  content  = "owner = workshop\n"
}
```

```hcl
provider "local" {}

# variable — a typed input, overridable at run time.
variable "owner" {
  type    = string
  default = "workshop"
}

resource "local_file" "summary" {
  filename = "build/summary.txt"
  content  = "owner = ${var.owner}\n"   # reference!
}
```

```hcl
provider "local" {}

variable "owner" {
  type    = string
  default = "workshop"
}

resource "local_file" "summary" {
  filename = "build/summary.txt"
  content  = "owner = ${var.owner}\n"
}

# output — surface a value after apply.
output "summary_path" {
  value = local_file.summary.filename   # reference!
}
```
````

::right::

<div class="mt-4">
  <KwCard heading="provider → resource" kind="resource" variant="ok">
    Declare the plugin, then the one block that <strong>creates</strong>: a file
    OpenTofu now owns.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="variable → output" variant="ok">
    A typed <strong>input</strong> feeds the resource via <code>var.owner</code>;
    an <strong>output</strong> reads back via
    <code>local_file.summary.filename</code>. Those <code>${…}</code> and dotted
    names are <strong>references</strong> — the next slide.
  </KwCard>
  </div>
</div>

<!--
Say: Watch a config grow, block by block, via magic-move. Start with just the
provider. Add the resource — the only block that creates a real object, here a
managed file. Add a variable and thread it into the resource with the reference
${var.owner}. Finally add an output that reads the resource's filename back. Call
out the two references as they appear: var.owner and local_file.summary.filename —
that's how blocks connect. This four-block shape is the spine of the config you
build in Lab 02; the lab's tracked main.tf adds locals, data, and a module too. The
slide HCL is illustrative — the lab file is the source of truth. (~5 min)
Then: "Those dotted names are the wiring — let's make references explicit."
-->

---
clicks: 4
---

<span class="kw-kicker">The wiring</span>

# References & interpolation

<div class="mt-6 space-y-3">
  <div class="flex items-center gap-4">
    <KwChip>var.owner</KwChip>
    <span>read a <strong>variable's</strong> value</span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip>local.banner</KwChip>
    <span>read a computed <strong>local</strong></span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip>data.local_file.motd.content</KwChip>
    <span>read an attribute of a <strong>data</strong> source</span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip>random_pet.id.id</KwChip>
    <span>read a <strong>resource's</strong> attribute — <code>&lt;type&gt;.&lt;name&gt;.&lt;attr&gt;</code></span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip variant="ok">module.greeting.message</KwChip>
    <span>read a <strong>module's</strong> output</span>
  </div>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Wrap any reference in `"${…}"` to interpolate it into a string. OpenTofu resolves
every reference at **plan time** and builds a **dependency graph** from them — so
order in the file doesn't matter, only what references what.

</div>

<!--
Say: References are how blocks connect, revealed one line at a time. var.owner
reads a variable. local.banner reads a computed local. data.local_file.motd.content
reads an attribute off a data source. random_pet.id.id reads a resource attribute —
the pattern is type dot name dot attribute. module.greeting.message reads a module
output. Final click: wrap any of these in "${}" to drop it into a string, and know
that OpenTofu resolves every reference at plan time and builds a dependency graph
from them — which is why file order never matters, only what references what. That
graph is exactly what makes the undeclared-reference error in the lab possible. (~4
min)
Then: "One practical note before the lab: the files themselves and the .tofu
extension."
-->

---

<span class="kw-kicker">Files on disk</span>

# Files & the `.tofu` extension

<div class="kw-cols-2 mt-6">
  <KwCard heading="Every .tf in a dir is one config" variant="ok">
    OpenTofu <strong>concatenates</strong> all <code>*.tf</code> files in a
    directory. Split by concern — <code>main.tf</code>, <code>variables.tf</code>,
    <code>outputs.tf</code> — it's the same config either way.
  </KwCard>
  <KwCard heading="…and .tofu works too" variant="ok">
    OpenTofu also reads the <code>.tofu</code> extension. A <code>.tofu</code> file
    <strong>wins over</strong> a same-named <code>.tf</code> — handy for OpenTofu-only
    overrides while staying Terraform-compatible.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Order across files never matters — the dependency graph, not file layout, decides
what runs when.

</div>

<!--
Say: A practical note on files. OpenTofu treats every .tf file in a directory as
one merged config, so you split by concern — main, variables, outputs — purely for
readability; it's identical to one big file. OpenTofu also accepts the .tofu
extension, and a .tofu file takes precedence over a same-named .tf, which lets you
add OpenTofu-only overrides while keeping a Terraform-compatible .tf. Click: and
because references build the graph, order across files never matters. (~3 min)
Then: "Now build one yourself — Lab 02."
-->

---
layout: lab
lab: labs/day-1/02-hcl-blocks.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 02 — HCL & the building blocks

Read and run one small config that uses **every core block type** —
`provider`, `variable`, `locals`, `data`, `resource`, `module`, `output` — and
watch references wire them into a dependency graph. Then **break it on purpose**:
reference an undeclared variable, read the `plan` error, and fix it by declaring
the block OpenTofu asks for.

Every task and question has a `<details>` spoiler; panic reset is `tofu destroy`
plus `rm`.

<!--
Say: Set up the lab. You'll cat and run a single tracked config that exercises all
seven block types, then read the generated file line by line to see each reference
resolve. The payoff is the break-fix: add a scratch file that references
var.maintainer without declaring it, watch plan refuse with "Reference to
undeclared input variable," then declare the variable and watch plan go green. Every
task and question has a spoiler; panic reset is tofu destroy plus rm — nothing
cloud, nothing to leak. (~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: HCL & building blocks — recap
story: 'HCL is blocks of arguments whose values are expressions — seven block types, wired by references.'
next: 'Next: Core workflow (init/plan/apply/destroy)'
---

- **HCL grammar** is just three things: **blocks** (header + `{ }`), **arguments** (`name = value`), and **expressions** (the value side).
- **Seven core block types:** `resource`, `variable`, `output`, `provider`, `data`, `locals`, `module` — plus the top-level `terraform {}` settings block.
- Only **`resource`** blocks create, change, or destroy real objects; the rest configure, compute, read, or report.
- **References** (`var.*`, `local.*`, `data.*.*`, `<res>.*`, `module.*.*`), wrapped in `"${…}"`, wire blocks into a **dependency graph** resolved at plan time.
- Every `*.tf` in a directory is one merged config; OpenTofu also reads **`.tofu`** (which wins over a same-named `.tf`).

<!--
Say: Pull the threads together. HCL is three things — blocks, arguments,
expressions. There are seven core block types plus the terraform settings block,
and of those only resource actually changes the world. References — var, local,
data, resource attributes, module outputs — wrapped in "${}" wire everything into a
dependency graph that OpenTofu resolves at plan time, which is why file order never
matters. And every .tf in a directory is one config, with .tofu accepted too and
taking precedence. (~2 min)
Then: transition into S03 — the core workflow, init/plan/apply/destroy.
-->
