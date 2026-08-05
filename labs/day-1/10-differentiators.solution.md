# Lab 10 — OpenTofu differentiators: provider `for_each` & `-exclude` (S10) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/10-differentiators/` unless a step says otherwise.

### Step 0 — Bring up LocalStack

```bash
task lab:up                     # start LocalStack on :4566, wait for healthy
cd labs/day-1/10-differentiators
```

---

<details><summary>Expected output</summary>

```console
$ task lab:up
Waiting for LocalStack to become healthy at http://localhost:4566/_localstack/health ...
LocalStack is healthy -> http://localhost:4566
```

</details>

---

### Step 1 — `init`: one provider block, note the warning

```bash
tofu init
```

**Task:** `init` prints a **warning** before it succeeds. Read it — what is it
telling you, and why does it fire for *this* config?

---

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

### Step 2 — Apply: one bucket per region, through its own provider

```bash
tofu apply -auto-approve
```

**Task:** How many resources apply, and — the whole point — did each bucket land
in its **own** region?

---

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

### Step 3 — `-exclude` (1.9): plan/apply all *but* one address

`-exclude` is the inverse of `-target`: it plans everything **except** the address
you name (and anything downstream of it). First the clean case. Reset state so the
counts are unambiguous, then apply while excluding **one region's leaf object**:

```bash
tofu destroy -auto-approve
tofu apply -auto-approve -exclude='aws_s3_object.marker["eu-west-1"]'
```

**Task:** How many resources apply now, and which one is missing?

**Now the honest edge — exclude a *dependency*.** Reset, then try to exclude one
region's **bucket** while its object is still in the config:

```bash
tofu destroy -auto-approve
tofu plan -exclude='aws_s3_bucket.regional["eu-west-1"]'
```

**Task:** You excluded the bucket, *not* the object. Does the object still get
created? What does that tell you about how `-exclude` treats dependencies?

---

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

### Step 4 — Break → fix: the provider-`for_each` removal error

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

## Cleanup / panic reset

```bash
cd labs/day-1/10-differentiators
git checkout -- providers.tf                            # restore canonical providers before destroy (Step 4 shrink breaks provider instances)
tofu destroy -auto-approve                              # remove all buckets + objects (needs LocalStack up)
rm -rf .terraform .terraform.lock.hcl
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # sweep state/backup safely
task lab:down                                           # stop LocalStack, remove volumes
git status --short .                                    # expect: no output
```

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

## Expected state / output

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

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

OpenTofu reconciles declared configuration against stored state on every plan and
apply, so the commands above succeed only when the tracked HCL, provider plugins,
and backend settings match what the lab authored. Each step therefore wires inputs
(outputs, variables, modules, or data sources) before the resources that consume
them, because the graph must be acyclic at evaluation time.

When a step reads remote or emulated cloud APIs (LocalStack or mock providers), the
provider block binds credentials and endpoints first; resources then call those APIs
and persist returned attributes into state. That is why init/plan/apply ordering
matters and why re-running apply without changes reports zero additions.

## Troubleshooting and recovery

If a step fails mid-lab, prefer the documented panic reset before editing tracked files by hand:

```bash
cd labs/day-1/10-differentiators
git checkout -- providers.tf                            # restore canonical providers before destroy (Step 4 shrink breaks provider instances)
tofu destroy -auto-approve                              # remove all buckets + objects (needs LocalStack up)
rm -rf .terraform .terraform.lock.hcl
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # sweep state/backup safely
task lab:down                                           # stop LocalStack, remove volumes
git status --short .                                    # expect: no output
```

Nothing is created on real AWS, so there is nothing to bill or leak. The
generated state / `.terraform` files are gitignored. Checkout still comes first
even when LocalStack must be running for destroy — a Step-4 `providers.tf` edit
left unreverted makes destroy fail on missing provider instances.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.

Re-enter `labs/day-1/10-differentiators/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- **Add a third region.** Append `ap-southeast-1` to `local.regions` and apply —
- **Retire a region the right way.** From the full four-resource state, first
- **Make the exclude edge instance-precise.** In Step 3 you saw that excluding one

Example verification from the workdir:

```bash
cd labs/day-1/10-differentiators
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
