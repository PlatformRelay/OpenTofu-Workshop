# Lab 10 — OpenTofu differentiators: provider `for_each`, `-exclude` & `import` (S10)

| | |
| --- | --- |
| **Section** | S10 — OpenTofu differentiators *(recommended · Day 1)* |
| **Environment** | `localstack ✓` — needs Docker for LocalStack on `:4566`; no real AWS, no cost |
| **Estimated time** | 55 min |

## Objective

Two OpenTofu-first features you cannot express in Terraform, then the
adopt-existing-infrastructure skill you will use on day one of a real job —
all driven against real resources on LocalStack:

1. **Provider `for_each` (1.9)** — a *single* `provider "aws"` block fanned out
   over a set of regions, one instance per region, then a regional S3 bucket
   created *through* each instance. In Terraform you hand-write one aliased
   provider block per region; here one declaration covers all of them.
2. **`-exclude` (1.9)** — plan/apply everything *except* a named address. You will
   see the clean case (drop a leaf) and the honest edge (drop a dependency — its
   dependents go with it).
3. **`import` — state adoption (Part B)** — a bucket that already exists (created
   behind OpenTofu's back with `awslocal`) is brought under management with a
   declarative `import {}` block: plan shows **`1 to import`**, apply reports
   **`1 imported`**, and the follow-up plan is a clean no-op. You will mis-key
   the `id`, adopt an object your config does not match, contrast the
   imperative `tofu import` CLI, and let `-generate-config-out` write (a draft
   of) the config for you.

Part A ends with a **break → fix** on the real provider-`for_each` gotcha:
remove a region while its resources still live in state and read the exact
error OpenTofu emits, then fix it. Part B has two of its own: a wrong import
`id`, and a config that disagrees with the real object.

> Part A's pasted output was captured on **`tofu v1.12.3`**, Part B's on
> **`tofu v1.12.5`**, both against **`localstack/localstack:4.9.2`**. All
> pasted output is from a real run.

## Prerequisites

- `tofu` ≥ 1.9 — provider `for_each` and `-exclude` are 1.9 features. Check:
  `tofu version`. (Part B's `import` block needs only ≥ 1.7 — the loopable
  `for_each` import floor — so the 1.9 floor covers it.)
- Docker for LocalStack. Check: `docker version`. Start LocalStack with
  `task lab:up` (Step 0).
- `awslocal` (the LocalStack AWS CLI wrapper) — **required in Part B**, where it
  plays the role of "someone who clicked around the console before you were
  hired": it creates the out-of-band bucket you then adopt. No host install
  needed — the LocalStack container ships it, so every `awslocal …` command in
  this lab also runs as
  `docker exec opentofu-workshop-localstack awslocal …`. In Part A it is only
  used in an optional cross-check spoiler.

## Files used

All tracked under `labs/day-1/10-differentiators/` — you run them, you do not
paste them. Part A is the flat root config (no child module — provider
`for_each` into modules carries extra constraints this lab does not need);
Part B has its own sibling workdir `import/` so the two state lifecycles never
mix.

### Part A — `labs/day-1/10-differentiators/`

`providers.tf` — the star of the lab. One `provider "aws"` block with
`for_each = local.regions` becomes one provider instance per region:

<!-- source: labs/day-1/10-differentiators/providers.tf -->
```hcl
# =============================================================================
# labs/day-1/10-differentiators — provider for_each (OpenTofu 1.9)
# =============================================================================
#
# The headline of this lab: a SINGLE provider block fanned out over many
# regions with `for_each` (OpenTofu 1.9). One declaration, one instance per
# region, each addressable as `aws.by_region["<region>"]`. Terraform has no
# equivalent — you would hand-write one aliased provider block per region.

terraform {
  # provider `for_each` is an OpenTofu 1.9 feature.
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0: provider v6's waiters are incompatible with LocalStack community
      # (last release 4.9.2). v5 applies clean against :4566.
      version = ">= 5.0, < 6.0"
    }
  }
}

# One shared source of truth for the region set. The provider `for_each` and
# every regional resource iterate THIS map, so their instance keys always align.
locals {
  regions = toset(["us-east-1", "eu-west-1"])
}

# -----------------------------------------------------------------------------
# provider for_each (OpenTofu 1.9) — one AWS provider instance PER region.
# `each.key` / `each.value` are the region string; every endpoint still points
# at LocalStack (:4566), so this runs with zero real AWS credentials and cost.
# -----------------------------------------------------------------------------
provider "aws" {
  alias    = "by_region"
  for_each = local.regions
  region   = each.value

  access_key = "test"
  secret_key = "test"

  # LocalStack has no real IAM/metadata/STS; skip those handshakes.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Path-style S3 addressing is required against LocalStack.
  s3_use_path_style = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}
```

`main.tf` — a regional bucket per region, and a leaf object that **depends on**
its bucket (that dependency is what the `-exclude` edge case hinges on). Each
resource selects its provider instance with `provider = aws.by_region[each.key]`:

<!-- source: labs/day-1/10-differentiators/main.tf -->
```hcl
# =============================================================================
# labs/day-1/10-differentiators — regional resources over the provider fan-out
# =============================================================================
#
# Two resources, each fanned out over the SAME `local.regions` set:
#
#   aws_s3_bucket.regional["<region>"]  — one bucket per region, created by that
#                                         region's provider instance.
#   aws_s3_object.marker["<region>"]    — a leaf that DEPENDS ON its region's
#                                         bucket. This dependency is what the
#                                         `-exclude` break -> fix hinges on.

# One regional bucket per region, each created THROUGH that region's provider
# instance: `provider = aws.by_region[each.key]` selects the matching instance.
resource "aws_s3_bucket" "regional" {
  for_each = local.regions
  provider = aws.by_region[each.key]

  # Bucket names are globally unique, so embed the region.
  bucket = "workshop-${each.key}-data"
}

# A leaf object per region that DEPENDS ON its region's bucket (via the
# `bucket` reference). Excluding a bucket while keeping its object is the
# broken `-exclude` the lab demonstrates.
resource "aws_s3_object" "marker" {
  for_each = local.regions
  provider = aws.by_region[each.key]

  bucket  = aws_s3_bucket.regional[each.key].id
  key     = "region.txt"
  content = "region=${each.key}\n"
}

output "bucket_names" {
  description = "The regional bucket name created per region."
  value       = { for k, b in aws_s3_bucket.regional : k => b.bucket }
}
```

> **Why one shared `local.regions` for both the provider and the resources?**
> It keeps the instance keys aligned — `aws.by_region["eu-west-1"]` always has a
> matching `aws_s3_bucket.regional["eu-west-1"]`. It also, deliberately, sets up
> the break→fix in Step 4: sharing the collection is exactly the pattern OpenTofu
> warns about, and you will make that warning fire for real. Hold that thought.

### Part B — `labs/day-1/10-differentiators/import/`

Three small files. `providers.tf` is the same LocalStack wiring as Part A,
collapsed to a single provider instance — the fan-out is Part A's lesson, not
this one's:

<!-- source: labs/day-1/10-differentiators/import/providers.tf -->
```hcl
# =============================================================================
# labs/day-1/10-differentiators/import — provider wiring (LocalStack)
# =============================================================================
#
# Part B of Lab 10: adopting EXISTING infrastructure with `import`.
# One plain provider instance is enough here — the fan-out lives in
# Part A's workdir one level up. Every endpoint points at LocalStack
# (:4566): zero real AWS credentials, zero cost.

terraform {
  # `import {}` blocks are core in every supported OpenTofu release;
  # the Stretch's `for_each` on an import block needs >= 1.7.
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0: provider v6's waiters are incompatible with LocalStack
      # community (last release 4.9.2). v5 runs clean against :4566.
      version = ">= 5.0, < 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  access_key = "test"
  secret_key = "test"

  # LocalStack has no real IAM/metadata/STS; skip those handshakes.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Path-style S3 addressing is required against LocalStack.
  s3_use_path_style = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}
```

`imports.tf` — the declarative adoption. This block is *planned* like any other
change:

<!-- source: labs/day-1/10-differentiators/import/imports.tf -->
```hcl
# Declarative adoption: an `import` block is PLANNED like any other
# change — reviewable in a diff, dry-runnable, and removable once the
# object is in state (it becomes a no-op after the importing apply).
#
# `to` is the config address that will own the object; `id` is the
# provider-native identifier of the REAL object (for S3: the bucket
# name). Lab 10's Step 5 creates that bucket out-of-band with
# awslocal — the "existing infrastructure" this part adopts.
import {
  to = aws_s3_bucket.adopted
  id = "workshop-adopted-logs"
}
```

`adopted.tf` — the config the adopted object must match:

<!-- source: labs/day-1/10-differentiators/import/adopted.tf -->
```hcl
# The config the adopted bucket must MATCH. Importing binds this block
# to the real object; it does NOT rewrite reality to fit your code.
# Any attribute that disagrees with the live object shows up in the
# importing plan as a change — the lab makes you read exactly that.
resource "aws_s3_bucket" "adopted" {
  bucket = "workshop-adopted-logs"

  tags = {
    # Matches the tag Step 5 puts on the real bucket. Delete this
    # attribute and the importing plan gains an in-place change.
    owner = "ops"
  }
}

output "adopted_bucket" {
  description = "Name of the bucket adopted into state by the import block."
  value       = aws_s3_bucket.adopted.bucket
}
```

> **Why does the resource block exist at all if the bucket is already real?**
> Because `import` only binds an address in *state* to an object in the world.
> The desired state stays whatever your config says — which is exactly what
> Step 7 weaponises: make the config disagree with reality and the importing
> plan gains an in-place change.

---

## Step 0 — Bring up LocalStack

```bash
task lab:up                     # start LocalStack on :4566, wait for healthy
cd labs/day-1/10-differentiators
```

<details><summary>Expected output</summary>

```console
$ task lab:up
Waiting for LocalStack to become healthy at http://localhost:4566/_localstack/health ...
LocalStack is healthy -> http://localhost:4566
```

</details>

---

## Step 1 — `init`: one provider block, note the warning

```bash
tofu init
```

**Task:** `init` prints a **warning** before it succeeds. Read it — what is it
telling you, and why does it fire for *this* config?

<details><summary>Solution / expected output</summary>

```console
$ tofu init

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 5.0.0, < 6.0.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed, key ID 0C0AF313E5FD9F80)
...
╷
│ Warning: Provider configuration for_each matches resource
│
│ This provider configuration uses the same for_each expression as a
│ resource, which means that subsequent removal of elements from this
│ collection would cause a planning error.
│
│ OpenTofu relies on a provider instance to destroy resource instances that
│ are associated with it, and so the provider instance must outlive all of
│ its resource instances by at least one plan/apply round. For removal of
│ instances to succeed in future you must structure the configuration so that
│ the provider block's for_each expression can produce a superset of the
│ instances of the resources associated with the provider configuration.
...
OpenTofu has been successfully initialized!
```

> Your resolved `hashicorp/aws` patch within `>= 5.0.0, < 6.0.0` may differ —
> match on the version *range* and the warning text, not the exact `v5.x.y`.

The provider `for_each` and both resources iterate the **same** `local.regions`
set. That is the simplest, clearest wiring — and it works — but OpenTofu warns
that if you later *shrink* the set while resources still exist, the provider
instance that owns those resources vanishes too, and there is nothing left to
destroy them with. This is a **warning, not an error**: `init` succeeds. You will
make it turn into a real error on purpose in Step 4.

</details>

---

## Step 2 — Apply: one bucket per region, through its own provider

```bash
tofu apply -auto-approve
```

**Task:** How many resources apply, and — the whole point — did each bucket land
in its **own** region?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
Plan: 4 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_names = {
      + eu-west-1 = "workshop-eu-west-1-data"
      + us-east-1 = "workshop-us-east-1-data"
    }
aws_s3_bucket.regional["eu-west-1"]: Creating...
aws_s3_bucket.regional["us-east-1"]: Creating...
aws_s3_bucket.regional["eu-west-1"]: Creation complete after 0s [id=workshop-eu-west-1-data]
aws_s3_bucket.regional["us-east-1"]: Creation complete after 0s [id=workshop-us-east-1-data]
aws_s3_object.marker["us-east-1"]: Creating...
aws_s3_object.marker["eu-west-1"]: Creating...
aws_s3_object.marker["us-east-1"]: Creation complete after 0s [id=region.txt]
aws_s3_object.marker["eu-west-1"]: Creation complete after 0s [id=region.txt]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

**4 resources** — a bucket and an object per region — with instance keys
namespaced by region: `["us-east-1"]` and `["eu-west-1"]`. Prove each bucket was
created by its region's provider instance by reading the region OpenTofu recorded
in state:

```console
$ tofu state show 'aws_s3_bucket.regional["eu-west-1"]'
# aws_s3_bucket.regional["eu-west-1"]:
resource "aws_s3_bucket" "regional" {
    bucket                      = "workshop-eu-west-1-data"
    region                      = "eu-west-1"
    ...
```

`region = "eu-west-1"` on that bucket — the `aws.by_region["eu-west-1"]` provider
instance placed it there. One `provider` block, two regions, zero aliased
copies. (If you have `awslocal` installed, `awslocal s3api list-buckets --query
'Buckets[].[Name,BucketRegion]'` shows the same `BucketRegion` per bucket.)

</details>

---

## Step 3 — `-exclude` (1.9): plan/apply all *but* one address

`-exclude` is the inverse of `-target`: it plans everything **except** the address
you name (and anything downstream of it). First the clean case. Reset state so the
counts are unambiguous, then apply while excluding **one region's leaf object**:

```bash
tofu destroy -auto-approve
tofu apply -auto-approve -exclude='aws_s3_object.marker["eu-west-1"]'
```

**Task:** How many resources apply now, and which one is missing?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve -exclude='aws_s3_object.marker["eu-west-1"]'
...
Plan: 3 to add, 0 to change, 0 to destroy.
aws_s3_bucket.regional["eu-west-1"]: Creating...
aws_s3_bucket.regional["us-east-1"]: Creating...
aws_s3_bucket.regional["eu-west-1"]: Creation complete after 0s [id=workshop-eu-west-1-data]
aws_s3_bucket.regional["us-east-1"]: Creation complete after 0s [id=workshop-us-east-1-data]
aws_s3_object.marker["us-east-1"]: Creating...
aws_s3_object.marker["us-east-1"]: Creation complete after 0s [id=region.txt]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

$ tofu state list
aws_s3_bucket.regional["eu-west-1"]
aws_s3_bucket.regional["us-east-1"]
aws_s3_object.marker["us-east-1"]
```

**3 added, not 4** — both buckets plus only the `us-east-1` object. The excluded
`aws_s3_object.marker["eu-west-1"]` is absent from state: `-exclude` dropped it
from the plan entirely. (You will also see a *Resource targeting is in effect*
warning — `-exclude`/`-target` are recovery tools, not routine workflow.)

</details>

**Now the honest edge — exclude a *dependency*.** Reset, then try to exclude one
region's **bucket** while its object is still in the config:

```bash
tofu destroy -auto-approve
tofu plan -exclude='aws_s3_bucket.regional["eu-west-1"]'
```

**Task:** You excluded the bucket, *not* the object. Does the object still get
created? What does that tell you about how `-exclude` treats dependencies?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -exclude='aws_s3_bucket.regional["eu-west-1"]'
...
  # aws_s3_bucket.regional["us-east-1"] will be created
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

**1 to add — just the `us-east-1` bucket. Both `marker` objects are gone.**
OpenTofu does **not** error here; it prunes the dependents. But note *how far* the
pruning reached: you excluded one bucket instance, yet **neither** object survived
— not even `us-east-1`'s, whose bucket is still being created.

Contrast with the clean case above. Excluding the `eu-west-1` **leaf object** was
instance-precise — only that one instance dropped, `us-east-1`'s object stayed.
Excluding the `eu-west-1` **bucket** pruned the *entire* `aws_s3_object.marker`
resource, both keys. The difference is the dependency edge: `marker` references
`aws_s3_bucket.regional[each.key]` through a **dynamic index**, so OpenTofu records
a coarse, **resource-to-resource** dependency (marker-depends-on-regional), not a
per-instance one. Exclude *any* instance of the bucket and the whole dependent
resource goes with it. The real lesson: `-exclude` drops the named address *and
everything downstream*, and when the downstream edge is resource-level, "downstream"
can be wider than you expect. Nothing is broken — this is `-exclude` behaving
correctly. (You also get the *Resource targeting is in effect* warning again.)

</details>

---

## Step 4 — Break → fix: the provider-`for_each` removal error

Remember the Step 1 warning? Now trigger it for real. First make sure all four
resources exist in state, then **shrink** `local.regions` while they are still
live:

```bash
tofu apply -auto-approve        # ensure all 4 resources are in state
```

Edit `providers.tf` and drop `eu-west-1` from the region set (temporarily):

```hcl
# EDIT (temporarily) — in providers.tf:
locals {
  regions = toset(["us-east-1"])
}
```

```bash
tofu plan
```

**Task:** What error do you get, and what does OpenTofu say caused it?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
╷
│ Error: Provider instance not present
│
│ To work with aws_s3_bucket.regional["eu-west-1"] its original provider
│ instance at
│ provider["registry.opentofu.org/hashicorp/aws"].by_region["eu-west-1"] is
│ required, but it has been removed. This occurs when an element is removed
│ from the provider configuration's for_each collection while objects created
│ by that the associated provider instance still exist in the state. Re-add
│ the for_each element to destroy aws_s3_bucket.regional["eu-west-1"], after
│ which you can remove the provider configuration again.
│
│ This is commonly caused by using the same for_each collection both for a
│ resource (or its containing module) and its associated provider
│ configuration. To successfully remove an instance of a resource it must be
│ possible to remove the corresponding element from the resource's for_each
│ collection while retaining the corresponding element in the provider's
│ for_each collection.
╵
```

This is exactly what Step 1 warned about. You removed `eu-west-1` from the shared
`local.regions`, so both the `eu-west-1` **resources** *and* the
`eu-west-1` **provider instance** disappeared in one edit. But the resources still
exist in state, and OpenTofu needs their original provider instance to destroy
them — which you just deleted. It refuses to proceed and tells you the fix in
plain terms: *"Re-add the for_each element to destroy … after which you can remove
the provider configuration again."*

</details>

**Fix:** put `eu-west-1` back — the tracked config is already correct, so just
restore that one line:

```hcl
# Restore in providers.tf:
locals {
  regions = toset(["us-east-1", "eu-west-1"])
}
```

```bash
tofu plan
```

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
No changes. Your infrastructure matches the configuration.
```

Re-adding the region brings its provider instance back, so the resources it owns
have somewhere to live again — plan is clean. The proper way to actually *remove*
a region is to keep it in the provider `for_each` for **one more apply** while you
drop it from the resources (destroying them through the still-present provider),
then remove it from the provider set. `git diff` now shows **no changes** to the
tracked files — the break was purely the temporary edit, and the fix reverted it.

</details>

---

## Part B — `import`: adopt infrastructure that already exists

The likeliest first task in a real OpenTofu job is not `plan`-from-scratch — it
is *adoption*: infrastructure someone built by hand (console, CLI, another
tool) that must come under management **without being destroyed and
recreated**. This part manufactures that situation honestly: `awslocal`
creates a bucket behind OpenTofu's back, and you bring it into state with a
declarative `import {}` block, hit the two classic failure modes on the way,
then contrast the older imperative CLI and the config generator.

> **Scope note:** like all of Lab 10, Part B stands apart from the
> `service-manifest` project — nothing is carried forward and nothing is
> retired; the spine continues untouched in the Day-2 labs.

Work in the **sibling workdir** so Part A's state stays untouched:

```bash
cd labs/day-1/10-differentiators/import   # from the repo root
```

(LocalStack must still be up from Step 0 — `task lab:up` if you tore it down.)

---

## Step 5 — Manufacture the "existing infrastructure", out-of-band

Someone-who-isn't-OpenTofu creates a tagged bucket. Play that someone:

```bash
awslocal s3 mb s3://workshop-adopted-logs
awslocal s3api put-bucket-tagging --bucket workshop-adopted-logs \
  --tagging 'TagSet=[{Key=owner,Value=ops}]'
awslocal s3api get-bucket-tagging --bucket workshop-adopted-logs
tofu init
```

> No `awslocal` on your host? The LocalStack container ships it — prefix any of
> these with `docker exec opentofu-workshop-localstack` instead (e.g.
> `docker exec opentofu-workshop-localstack awslocal s3 mb …`).

**Task:** After `init` succeeds, run `tofu state list`. It does not print a
list — it **errors**. Read the error: why is it the whole point of this part?

<details><summary>Solution / expected output</summary>

```console
$ awslocal s3 mb s3://workshop-adopted-logs
make_bucket: workshop-adopted-logs

$ awslocal s3api get-bucket-tagging --bucket workshop-adopted-logs
{
    "TagSet": [
        {
            "Key": "owner",
            "Value": "ops"
        }
    ]
}

$ tofu init

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 5.0.0, < 6.0.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed, key ID 0C0AF313E5FD9F80)
...
OpenTofu has been successfully initialized!
```

> Your resolved `hashicorp/aws` patch within `>= 5.0.0, < 6.0.0` may differ —
> match on the version *range*, not the exact `v5.x.y`.

```console
$ tofu state list

Error: No state file was found

State management commands require a state file. Run this command in a
directory where OpenTofu has been run or use the -state flag to point the
command to a specific state location.
```

`tofu state list` cannot even print an *empty* list — it exits non-zero,
because after a fresh `init` there is **no state file at all**: `init` wires
up backend and providers, but only the first apply (or import) writes state.
The error *is* the evidence — the bucket is real (the tagging round-trip
proves it), yet OpenTofu holds no record of it. Reality and state disagree,
and *nothing* in the core workflow you learned in S03 will reconcile that
direction: `apply` would try to **create** a second `workshop-adopted-logs`
and fail on the name collision. Adoption needs its own verb.

</details>

---

## Step 6 — The importing plan: read all four numbers

The tracked config already contains the adoption wiring — an `import` block
(`imports.tf`) naming the real object's `id`, and the resource block
(`adopted.tf`) that will own it. Plan:

```bash
tofu plan
```

**Task:** Find the plan summary line. It has **four** numbers now — what does
each say? And where did attribute values like `grant`/`versioning` come from —
you never wrote them?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
aws_s3_bucket.adopted: Preparing import... [id=workshop-adopted-logs]
aws_s3_bucket.adopted: Refreshing state... [id=workshop-adopted-logs]

OpenTofu will perform the following actions:

  # aws_s3_bucket.adopted will be imported
  # (imported from "workshop-adopted-logs")
    resource "aws_s3_bucket" "adopted" {
        arn                         = "arn:aws:s3:::workshop-adopted-logs"
        bucket                      = "workshop-adopted-logs"
        id                          = "workshop-adopted-logs"
        region                      = "us-east-1"
        tags                        = {
            "owner" = "ops"
        }
        ...

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + adopted_bucket = "workshop-adopted-logs"
```

**`1 to import, 0 to add, 0 to change, 0 to destroy`** — the target you always
want when adopting. *Import* means "bind the real object to
`aws_s3_bucket.adopted` in state"; *0 to add* means nothing new gets created;
and — the number people skip — **`0 to change`** means your config already
matches the real object, so adoption will not mutate it. Every attribute you
never wrote (`grant`, `versioning`, `arn`, …) was **read from the live
bucket** during the `Refreshing state...` line: an import plan starts by
asking the provider what actually exists. This is the OpenTofu-recommended
declarative form — the block is plannable, reviewable in a diff, and (since
1.7) even loopable with `for_each` (Stretch).

</details>

---

## Step 7 — Break → fix ×2: wrong `id`, then a config that lies

**Break 1 — mis-key the `id`.** The most common real-world import failure is
simply naming an object that is not there (typo, wrong account, wrong region).
Edit `imports.tf` and drop the trailing `s` (temporarily):

```hcl
# EDIT (temporarily) — in imports.tf:
  id = "workshop-adopted-log"
```

```bash
tofu plan
```

**Task:** What error do you get — and at which workflow stage does it arrive?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
aws_s3_bucket.adopted: Preparing import... [id=workshop-adopted-log]
aws_s3_bucket.adopted: Refreshing state... [id=workshop-adopted-log]

Planning failed. OpenTofu encountered an error while generating this plan.


Error: Cannot import non-existent remote object

While attempting to import an existing object to "aws_s3_bucket.adopted", the
provider detected that no object exists with the given id. Only pre-existing
objects can be imported; check that the id is correct and that it is
associated with the provider's configured region or endpoint, or use "tofu
apply" to create a new remote object for this resource.
```

It fails **at plan time** — before anything could be touched. That is the
declarative form earning its keep: a mis-keyed adoption is caught in review,
not mid-apply. The error even lists the real-world suspects: wrong id, wrong
region, wrong endpoint.

**Fix:** restore the tracked line (`git checkout -- imports.tf` works too):

```hcl
# Restore in imports.tf:
  id = "workshop-adopted-logs"
```

</details>

**Break 2 — config that doesn't match the object.** Delete the whole
`tags = { … }` attribute from `adopted.tf` (temporarily), then plan again.

**Task:** The plan still succeeds. So what changed — and why is this the
sneakier failure mode?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
aws_s3_bucket.adopted: Preparing import... [id=workshop-adopted-logs]
aws_s3_bucket.adopted: Refreshing state... [id=workshop-adopted-logs]

OpenTofu will perform the following actions:

  # aws_s3_bucket.adopted will be updated in-place
  # (imported from "workshop-adopted-logs")
  ~ resource "aws_s3_bucket" "adopted" {
        bucket                      = "workshop-adopted-logs"
      + force_destroy               = false
        id                          = "workshop-adopted-logs"
      ~ tags                        = {
          - "owner" = "ops" -> null
        }
      ~ tags_all                    = {
          - "owner" = "ops" -> null
        }
        ...
    }

Plan: 1 to import, 0 to add, 1 to change, 0 to destroy.
```

**`1 to change`** — no error, no warning, just a different number. Importing
binds the object to *your* config, and your config now says "no tags", so the
very same apply that adopts the bucket would also **strip the `owner` tag from
it**. On a real estate this is how adoptions silently delete someone's
monitoring tag or lifecycle rule. The discipline this teaches: an import is
not done when the plan succeeds — it is done when the summary reads
**`0 to change`**. Converge your config *to reality*, not the other way
around, unless you explicitly decide the object should change.

**Fix:** restore the attribute (`git checkout -- adopted.tf`), plan, and
confirm the summary is back to `1 to import, 0 to add, 0 to change`.

</details>

---

## Step 8 — Apply the adoption, then prove convergence

```bash
tofu apply -auto-approve
tofu plan
tofu state list
```

**Task:** What does the apply summary call what happened? And what does the
still-present `import` block in `imports.tf` do on the follow-up plan?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
aws_s3_bucket.adopted: Importing... [id=workshop-adopted-logs]
aws_s3_bucket.adopted: Import complete [id=workshop-adopted-logs]

Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.

Outputs:

adopted_bucket = "workshop-adopted-logs"

$ tofu plan

No changes. Your infrastructure matches the configuration.

$ tofu state list
aws_s3_bucket.adopted
```

**`1 imported, 0 added, 0 changed`** — adoption, not creation: the bucket was
never recreated, it just gained an owner. The follow-up plan is the proof of
convergence (`No changes.`), and note it did **not** complain about the
`import` block still sitting in `imports.tf`: once `to` is already in state,
the block is a no-op. Teams typically delete import blocks in the next
commit after the adoption lands — they are scaffolding, not architecture.

</details>

---

## Step 9 — The imperative ancestor: `tofu import` (CLI)

Before config-driven import existed (1.5-lineage; in OpenTofu since its first
release), adoption was a CLI one-liner — and you will still meet it in
runbooks. Un-adopt the bucket (state only! — `state rm` is the Lab 04 verb
that *forgets* without destroying), then re-adopt it imperatively:

```bash
tofu state rm aws_s3_bucket.adopted
tofu import aws_s3_bucket.adopted workshop-adopted-logs
tofu plan
```

**Task:** Same end state as Step 8 — so name two concrete things the CLI form
did *not* give you on the way there.

<details><summary>Solution / expected output</summary>

```console
$ tofu state rm aws_s3_bucket.adopted
Removed aws_s3_bucket.adopted
Successfully removed 1 resource instance(s).

$ tofu import aws_s3_bucket.adopted workshop-adopted-logs
aws_s3_bucket.adopted: Importing from ID "workshop-adopted-logs"...
aws_s3_bucket.adopted: Import prepared!
  Prepared aws_s3_bucket for import
aws_s3_bucket.adopted: Refreshing state... [id=workshop-adopted-logs]

Import successful!

The resources that were imported are shown above. These resources are now in
your OpenTofu state and will henceforth be managed by OpenTofu.

$ tofu plan

No changes. Your infrastructure matches the configuration.
```

What the CLI skipped: **(1) there was no plan** — state was mutated the moment
you pressed enter, with no preview of whether your config matched (a Step-7
"Break 2" mismatch would surface only in the *next* plan, after the fact);
**(2) there is no reviewable artifact** — nothing lands in the diff for a
colleague to approve, and nothing replays in CI; it is also one address per
invocation, where the block form loops with `for_each`. Same destination,
none of the guardrails: prefer the `import` block; keep the CLI for quick
one-off surgery.

</details>

---

## Step 10 — `-generate-config-out`: let OpenTofu draft the config

Adopting a fleet nobody has config for means writing every resource block by
hand — unless you ask the plan to draft them. Manufacture a second orphan,
declare *only* an import block for it (no resource block — that is the point),
and ask for generated config. Create `import-media.tf` in the workdir (it is
gitignored learner-scratch) with exactly this content:

```hcl
# Learner-scratch (gitignored): an import block with NO resource config.
# `-generate-config-out` will author the resource block for us.
import {
  to = aws_s3_bucket.media
  id = "workshop-adopted-media"
}
```

```bash
awslocal s3 mb s3://workshop-adopted-media
tofu plan -generate-config-out=generated.tf
```

**Task:** The plan **fails** — but look at the two errors, then open
`generated.tf`. What did OpenTofu write, and why is the failure part of the
feature?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -generate-config-out=generated.tf
aws_s3_bucket.media: Preparing import... [id=workshop-adopted-media]
aws_s3_bucket.media: Refreshing state... [id=workshop-adopted-media]
aws_s3_bucket.adopted: Refreshing state... [id=workshop-adopted-logs]

Planning failed. OpenTofu encountered an error while generating this plan.


Error: Conflicting configuration arguments

  with aws_s3_bucket.media,
  on generated.tf line 1:
  (source code not available)

"bucket": conflicts with bucket_prefix

Error: Conflicting configuration arguments

  with aws_s3_bucket.media,
  on generated.tf line 2:
  (source code not available)

"bucket_prefix": conflicts with bucket
```

The draft was still written:

```console
$ cat generated.tf
# __generated__ by OpenTofu
# Please review these resources and move them into your main configuration files.

# __generated__ by OpenTofu
resource "aws_s3_bucket" "media" {
  bucket              = "workshop-adopted-media"
  bucket_prefix       = ""
  force_destroy       = null
  object_lock_enabled = false
  tags                = {}
  tags_all            = {}
}
```

The generator works from what the provider *read back*, so it emits every
attribute it saw — including the mutually-exclusive pair
`bucket`/`bucket_prefix`, which no human would write together. That is why
the file opens with "**Please review**": generated config is a *draft* for
you to edit down, not config to commit blind. The plan failing on its own
output is the review gate working.

One more honesty note: config generation is **experimental**, and OpenTofu
says so itself — a run where generation *succeeds* stamps the plan with
`Warning: Config generation is experimental` ("the generated configuration
format may change in future versions"). This run failed, and v1.12.5 then
prints only the errors: the paste above is the complete output — there is no
warning to elide. Draft, from an experimental generator: review it twice.

</details>

**Fix — prune the draft, then adopt.** Delete the `bucket_prefix`,
`force_destroy`, and `tags_all` lines from `generated.tf` (computed and
conflicting noise), then:

```bash
tofu plan
tofu apply -auto-approve
tofu state list
```

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

$ tofu apply -auto-approve
...
Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.

$ tofu state list
aws_s3_bucket.adopted
aws_s3_bucket.media
```

Down to the honest attributes, the draft plans exactly like Step 6's
hand-written config — `1 to import, 0 to change` — and the apply adopts the
second bucket. In a real adoption you would now move the pruned block out of
`generated.tf` into your real layout and delete both scratch files; here the
Cleanup does that for you.

</details>

## Expected observations

- One `provider "aws"` block with `for_each = local.regions` yields one instance
  per region (`aws.by_region["us-east-1"]`, `aws.by_region["eu-west-1"]`); each
  resource picks its instance with `provider = aws.by_region[each.key]`. Terraform
  needs one aliased provider block per region.
- Apply lands **4 resources**; `tofu state show` records `region = "eu-west-1"` on
  the eu bucket — proof the fan-out worked.
- `-exclude` (1.9) plans everything **but** the named address **and its
  dependents**: excluding a leaf object is instance-precise (3 added — only that
  one object drops); excluding one bucket instance prunes the *entire* dependent
  `marker` resource (1 to add — **both** objects gone, even `us-east-1`'s),
  because the dependency edge is resource-level. No error either way.
- Sharing one `for_each` collection between a provider and its resources is
  convenient but couples their lifecycles: shrink the set with resources still in
  state and you get **`Error: Provider instance not present`**. The fix is to
  re-add the element, then retire it over two applies.
- **Part B:** a real-but-unmanaged object shows up in `awslocal` while
  `tofu state list` errors **`No state file was found`** — before the first
  apply/import there is no state at all; the `import {}` block closes that gap
  **at plan time** —
  `Plan: 1 to import, 0 to add, 0 to change, 0 to destroy`, then
  `Apply complete! Resources: 1 imported`. A wrong `id` fails the plan
  (`Cannot import non-existent remote object`); a config that disagrees with
  the object turns the same plan into `1 to import, … 1 to change` — adoption
  is finished at **`0 to change`**, not at "plan succeeded".
- The imperative `tofu import` CLI reaches the same state with no plan preview
  and no reviewable diff; `-generate-config-out` writes a **draft** resource
  block (complete with a `bucket`/`bucket_prefix` conflict you must prune) —
  review is mandatory, by design.

## Cleanup / panic reset

Both parts, in one pass, from the **repo root**. Destroys run before scratch
removal — the scratch files are the only config OpenTofu has for the adopted
`media` bucket, so deleting them first would orphan it.

```bash
# Part A — restore canonical providers BEFORE destroy (Step 4 shrink breaks provider instances)
git checkout -- labs/day-1/10-differentiators
tofu -chdir=labs/day-1/10-differentiators destroy -auto-approve          # needs LocalStack up
rm -rf labs/day-1/10-differentiators/.terraform labs/day-1/10-differentiators/.terraform.lock.hcl
find labs/day-1/10-differentiators -maxdepth 1 -name 'terraform.tfstate*' -delete

# Part B — destroy removes the adopted buckets too (adopted objects are fully managed)
tofu -chdir=labs/day-1/10-differentiators/import destroy -auto-approve   # needs LocalStack up
rm -f labs/day-1/10-differentiators/import/import-media.tf labs/day-1/10-differentiators/import/generated.tf labs/day-1/10-differentiators/import/fleet.tf
rm -rf labs/day-1/10-differentiators/import/.terraform labs/day-1/10-differentiators/import/.terraform.lock.hcl
find labs/day-1/10-differentiators/import -maxdepth 1 -name 'terraform.tfstate*' -delete

task lab:down                                           # stop LocalStack, remove volumes
git status --short labs/day-1/10-differentiators        # expect: no output
```

> Ran Part B only up to Step 5 (bucket created, never imported)? `destroy`
> cannot remove what state never held — sweep the orphans directly:
> `awslocal s3 rb s3://workshop-adopted-logs --force` (and likewise
> `workshop-adopted-media`). `task lab:down` removes the LocalStack volume, so
> a full down/up also guarantees a clean slate.

Nothing is created on real AWS, so there is nothing to bill or leak. The
generated state / `.terraform` files are gitignored. Checkout still comes first
even when LocalStack must be running for destroy — a Step-4 `providers.tf` edit
left unreverted makes destroy fail on missing provider instances.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.

## Stretch (optional)

- **Add a third region.** Append `ap-southeast-1` to `local.regions` and apply —
  one edit adds a provider instance *and* a bucket + object for the new region.
  Contrast the diff size with what adding a region costs under one-aliased-block-
  per-region.
- **Retire a region the right way.** From the full four-resource state, first
  remove `eu-west-1` from *only* the resources' `for_each` (keep it in the
  provider set) and apply — watch the eu resources destroy through the still-live
  provider instance. *Then* drop it from the provider set. No error, because the
  provider outlived its resources by one apply — the exact sequence the Step 4
  error told you to follow.
- **Make the exclude edge instance-precise.** In Step 3 you saw that excluding one
  bucket instance prunes the *whole* `marker` resource, because `marker` indexes the
  bucket dynamically. Try `tofu plan -exclude='aws_s3_bucket.regional["eu-west-1"]'`
  from empty state and confirm `Plan: 1 to add` with **no** `marker` instances at
  all. Then reason about what a *static* reference (a single-region config with
  `bucket = aws_s3_bucket.one.id`) would exclude instead — the granularity of the
  dependency edge decides how far the exclusion reaches.
- **Adopt a fleet with one loopable `import` (1.7).** In the `import/` workdir,
  manufacture two more orphans
  (`awslocal s3 mb s3://workshop-adopted-alpha`, `…-beta`), then create a
  gitignored scratch `fleet.tf` holding a `local.fleet = toset(["alpha", "beta"])`,
  **one** `import` block with `for_each = local.fleet`
  (`to = aws_s3_bucket.fleet[each.key]`, `id = "workshop-adopted-${each.key}"`),
  and a matching `for_each` resource. Plan, and confirm
  `Plan: 2 to import, 0 to add, 0 to change, 0 to destroy` — a whole fleet
  adopted declaratively in one reviewable block, where the CLI form would be one
  invocation per object. Apply (`2 imported`), then run the Cleanup — its
  Part B block already sweeps `fleet.tf`.
