---
layout: section-cover
image: /covers/section-08-tagging-the-works.png
day: Day 1
section: '08'
tier: core
---

# Naming & labelling module

Two small, strictly-validated modules turn ad-hoc names and tags into a
machine-queryable convention — the flagship you build once and reuse everywhere.

---
layout: statement
kicker: 'The problem'
---

Ungoverned names and tags are **technical debt you can't query**.

`my-bucket-2`, `prod_bucket_FINAL`, a `Team` tag here and an `owner` tag there —
no cost allocation, no ownership, no policy. A module makes the convention the
**only** way to name and tag.

---

<span class="kw-kicker">Why it matters</span>

# What a naming & labelling convention buys you

<div class="kw-cols-3 mt-4">
  <KwCard heading="Findable" kind="resource" variant="accent">
    <strong>Deterministic names.</strong> One glance tells you the resource type,
    project, environment, and region — no guessing, no collisions.
  </KwCard>
  <KwCard heading="Chargeable" kind="module" variant="ok">
    <strong>Queryable tags.</strong> A fixed taxonomy (owner, cost-center,
    criticality) drives cost allocation, inventory, and policy.
  </KwCard>
  <KwCard heading="Enforced" kind="validation" variant="warn">
    <strong>Bad names can't ship.</strong> Validation + output preconditions
    reject a malformed name <em>before</em> it reaches a provider.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Built on <strong>US-0-MOD</strong>: the paired <code>modules/naming</code> and
<code>modules/labels</code> — pure computation, no cloud, fully unit-tested with
<code>tofu test</code>.

</div>

---
layout: code-annotated
heading: The naming module — compose a name field-by-field
lab: labs/day-1/08-naming-labels.md
---

```hcl {none|2-3|5|7-14|16|all}
locals {
  resource_short = lookup(var.resource_short_names, var.resource_type, "")
  env_short      = lookup(var.environment_short_names, var.environment, "")

  effective_suffix = var.suffix != null ? var.suffix : random_id.suffix[0].hex

  name_parts = compact([
    local.resource_short,
    var.project,
    local.env_short,
    var.location,
    var.description,
    local.effective_suffix,
  ])

  name = lower(join("-", local.name_parts))
}
```

::notes::

<CodeNote at="1" label="lookup(...)">
  Resolve a short code from a <strong>swappable profile</strong> map. Unknown key
  returns <code>""</code> — the output precondition turns that into a clear error.
</CodeNote>

<CodeNote at="2" label="effective_suffix" variant="warn">
  Explicit <code>suffix</code>, else a random 4-hex tail. <code>random_id</code> is
  <strong>unknown at plan time</strong> — remember this when you test.
</CodeNote>

<CodeNote at="3" label="compact([...])" variant="ok">
  Drops nulls <em>and</em> empty strings, so optional parts (location,
  description) simply vanish when omitted.
</CodeNote>

<CodeNote at="4" label="join + lower">
  <code>[short]-[project]-[env]-[location]-[desc]-[suffix]</code> →
  e.g. <code>s3-crmapp-d-euw1-web-a1f3</code>. Lowercased defensively.
</CodeNote>

---
layout: two-cols-code
heading: Validation is the module's contract
---

````md magic-move
```hcl
variable "project" {
  type = string
}
```

```hcl
variable "project" {
  type = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{3,9}$", var.project))
    error_message = "project must be 4-10 chars, lowercase letters/digits, starting with a letter."
  }
}
```

```hcl
output "name" {
  value = local.name

  precondition {
    condition     = contains(keys(var.resource_short_names), var.resource_type)
    error_message = "resource_type \"${var.resource_type}\" is not in resource_short_names."
  }
  precondition {
    condition     = length(local.name) < 64
    error_message = "composed name \"${local.name}\" is ${length(local.name)} chars; must be < 64."
  }
}
```
````

::right::

<div class="mt-4">
  <KwCard heading="variable validation" kind="validation" variant="warn">
    <strong>Reject at the door.</strong> A bad <code>project</code> fails before
    a single line of the module runs.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="output precondition" kind="output" variant="danger">
    <strong>Last line of defence.</strong> Even if a caller swaps in an odd
    profile, an unknown type or an over-long name can never <em>leave</em> the module.
  </KwCard>
  </div>
</div>

---

<span class="kw-kicker">S08-naming · the companion</span>

# The labels module — one taxonomy, every resource

<div class="grid grid-cols-2 gap-6 mt-4">
<div>

**Required (6)** — always present:

- `environment` · `criticality` · `project`
- `service` · `owner` · `cost-center`

**Optional (6)** — dropped when null, except `managed-by` (defaults `opentofu`, always emitted):

- `compliance` · `data-classification`
- `primary-contact` · `secondary-contact`
- `managed-by` · `iac-source-url`

</div>
<div>

```hcl
locals {
  optional_labels = {
    for k, v in local.optional_labels_raw :
    k => v if v != null
  }

  # taxonomy first, caller extras win last
  labels = merge(
    local.required_labels,
    local.optional_labels,
    var.additional_labels,
  )
}
```

<KwCard heading="tags = labels" kind="output" variant="ok" class="mt-3">
  The <code>tags</code> output is an alias of <code>labels</code> — AWS writes
  <code>tags =</code>, other clouds write <code>labels =</code>.
</KwCard>

</div>
</div>

---
layout: two-cols-code
heading: Wire both into real resources — the S05 ↔ S08 tie-in
---

```hcl
module "bucket_name" {
  source = "../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "web"
}

module "labels" {
  source = "../../modules/labels"

  environment = var.environment
  criticality = "high"
  project     = var.project
  service     = "web"
  owner       = var.owner
  cost_center = var.cost_center
}

resource "aws_s3_bucket" "web" {
  bucket = module.bucket_name.name
  tags   = module.labels.tags
}
```

::right::

<div class="mt-4">
  <KwCard heading="one demo root" kind="module" variant="accent">
    <code>examples/naming-labels-demo</code> names + tags an S3 bucket and a
    DynamoDB table, against <strong>LocalStack</strong> — zero cloud cost.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="encrypted state" kind="encryption" variant="ok">
    <strong>S05 lives here.</strong> The same root turns on
    <code>terraform { encryption {} }</code> — the flagship demo ships with its
    state encrypted.
  </KwCard>
  </div>
</div>

---
layout: code-annotated
heading: Test it with mock_provider — no cloud, no Docker
---

```hcl {none|1|4|7-9|all}
mock_provider "aws" { alias = "mock" }

run "unit_plan_with_mock" {
  command   = plan
  providers = { aws = aws.mock }

  assert {
    condition     = module.labels.labels["project"] == "crmapp"
    error_message = "project label should be crmapp"
  }
}
```

::notes::

<CodeNote at="1" label="mock_provider (aliased)" variant="danger">
  <strong>Aliased on purpose.</strong> A bare <code>mock_provider "aws"</code>
  would shadow <em>every</em> run — including apply tests — a false green.
</CodeNote>

<CodeNote at="2" label="command = plan" variant="ok">
  Pure plan against the mock. Runs anywhere, including CI with no Docker.
</CodeNote>

<CodeNote at="3" label="assert known parts">
  The composed <code>name</code> embeds a random suffix (unknown at plan), so the
  unit lane asserts the <strong>label map</strong>; full names are checked by the
  LocalStack apply test.
</CodeNote>

---
layout: lab
lab: labs/day-1/08-naming-labels.md
duration: 30 min
env: 'localstack ✓ · mock ✓ · real-aws (optional)'
---

# Lab 08 — name & tag with the flagship modules

Consume `modules/naming` + `modules/labels` through the
`examples/naming-labels-demo` root: run the mocked `tofu test` with **no cloud**,
bring up LocalStack and `apply` to see `s3-crmapp-d-web-<hex>` land with a full
tag map, then **break a naming validation** and read the error it throws.

Every task has a `<details>` spoiler; panic reset is `task lab:down`.

---
layout: recap
heading: Naming & labels — recap
story: 'Make the convention the only way to name and tag — then let validation enforce it.'
next: 'Next: Best practices — structure, lifecycle & refactoring'
---

- A **naming** module composes `[short]-[project]-[env]-[location]-[desc]-[suffix]`
  from swappable profiles; `compact()` drops what you omit.
- A **labels** module emits a 12-key taxonomy as `tags` — required keys enforced,
  null optionals dropped, `additional_labels` as an escape hatch.
- **Validation + output preconditions** mean a malformed name never reaches a provider.
- One demo root wires both into S3 + DynamoDB on **LocalStack**, with **S05
  encrypted state** turned on.
- `mock_provider` (aliased) unit-tests the whole thing with no cloud and no Docker.
