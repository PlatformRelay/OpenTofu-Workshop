---
layout: section-cover
image: /covers/section-10-the-advanced-rig.png
day: Day 1
section: '10'
tier: recommended
---

# OpenTofu differentiators

Since the fork, OpenTofu has shipped features Terraform has no answer to. Here's
the practitioner-facing set — a fan-out provider, a surgical plan filter, and
where they land on the release timeline.

<!--
Say: Frame the section as "what do you actually get by choosing OpenTofu." This is
not a licensing pitch — it's the concrete, hands-on features that have shipped
since the fork and that a practitioner uses in real configs. We'll walk the
release timeline so version claims are grounded, then focus on two features you
literally cannot write in Terraform: provider for_each and the -exclude plan
filter. The headline security feature, client-side state encryption, you've
already met — we'll point back to it, not re-teach it. (~1 min)
Then: "Start with the timeline so every version claim later is anchored."
-->

---
layout: statement
kicker: 'The reframe'
---

OpenTofu isn't "Terraform, but open" — it's **diverging on features**.

Same HCL, same core workflow, drop-in compatible — *and* a growing set of things
the Terraform CLI simply cannot do.

<!--
Say: Land the reframe. The easy assumption is that OpenTofu is just a
license-clean copy of Terraform — same tool, different governance. That was true
at 1.6; it is increasingly not true now. The HCL is the same, the plan/apply
workflow is the same, and existing configs are drop-in — but from 1.7 onward the
feature sets have diverged, and several OpenTofu features have no Terraform
equivalent at all. This section shows the practitioner-facing ones. (~2 min)
Then: "Here's the divergence, release by release."
-->

---
clicks: 6
---

<span class="kw-kicker">The divergence, release by release</span>

# One tool's feature timeline, 1.7 → 1.12

<div class="text-sm mt-4 space-y-2">
  <div v-click="1"><KwChip>1.7</KwChip> <strong>Client-side state &amp; plan encryption</strong> · provider-defined functions · <code>removed</code> block</div>
  <div v-click="2"><KwChip>1.8</KwChip> Early variable/backend evaluation · <code>.tofu</code> file extension · test <strong>mocking &amp; overrides</strong></div>
  <div v-click="3"><KwChip>1.9</KwChip> <strong>Provider <code>for_each</code></strong> · <strong><code>-exclude</code></strong> plan filter · cross-referencing variable validation</div>
  <div v-click="4"><KwChip>1.10</KwChip> <strong>OCI</strong> registry for providers &amp; modules · external key providers · native S3 state locking</div>
  <div v-click="5"><KwChip>1.11</KwChip> Ephemeral resources &amp; write-only attributes · <code>enabled</code> meta-arg</div>
  <div v-click="6"><KwChip>1.12</KwChip> Dynamic <code>prevent_destroy</code> · <code>destroy = false</code> (drop from state, keep remote) · concurrent provider install</div>
</div>

<div v-click="6" class="mt-6 kw-muted text-sm">

Current baseline: **OpenTofu 1.12.x** (supported to 2027-02-01). We'll dig into
the **1.9** pair — provider `for_each` and `-exclude` — in the lab.

</div>

<!--
Say: Click through the timeline so every later version claim is anchored. 1.7 is
the watershed — client-side state and plan encryption, provider-defined
functions, the removed block. 1.8 brings early evaluation, the .tofu extension,
and test mocking. 1.9 is our lab's release: provider for_each and the -exclude
filter. 1.10 is the platform-team release — OCI registries for providers AND
modules, external key providers, native S3 locking. 1.11 adds ephemeral resources
and write-only attributes. 1.12 is today's baseline, supported into 2027, with
dynamic prevent_destroy and the destroy-equals-false trick. Don't memorize all of
it — the point is the pace and that 1.9's pair is what you'll run. (~4 min)
Then: "Let's start with the headline you've already met — encryption."
-->

---
layout: statement
kicker: 'The headline you already met'
---

The flagship differentiator is **client-side state & plan encryption** (1.7).

You built it earlier in the day — `terraform { encryption {} }`, PBKDF2 → AES-GCM,
`fallback` to migrate. No Terraform equivalent. We won't re-teach it here.

<!--
Say: Set expectations honestly. The single biggest OpenTofu-only feature is
client-side encryption of state and plan, shipped in 1.7 — and you already built
it hands-on earlier today: the encryption block, a PBKDF2 key provider feeding an
AES-GCM method, and the fallback trick to migrate existing plaintext state. It has
no Terraform equivalent and it's the security reason many teams switch. Because
you've done it, we point back to it rather than repeat it, and spend this
section's time on two features you haven't seen yet. (~2 min)
Then: "The first of those — fanning a provider out over regions."
-->

---
layout: two-cols-code
heading: 'Provider for_each (1.9) — one block, many regions'
---

```hcl
locals {
  regions = toset(["us-east-1", "eu-west-1"])
}

# ONE provider block → one instance per region
provider "aws" {
  alias    = "by_region"
  for_each = local.regions
  region   = each.value
  # ...endpoints, credentials...
}

# each resource picks its instance by key
resource "aws_s3_bucket" "regional" {
  for_each = local.regions
  provider = aws.by_region[each.key]
  bucket   = "workshop-${each.key}-data"
}
```

::right::

<div class="mt-2">
  <KwCard heading="for_each on a provider" kind="module" variant="accent">
    A <strong>single</strong> <code>provider</code> block becomes one instance per
    key — <code>aws.by_region["us-east-1"]</code>, <code>["eu-west-1"]</code>, …
  </KwCard>
  <div class="mt-3">
  <KwCard heading="provider = alias[key]" kind="resource" variant="ok">
    A resource selects its instance with
    <code>provider&nbsp;=&nbsp;aws.by_region[each.key]</code>. Add a region → one
    edit fans out everything.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="Terraform: n/a" kind="validation" variant="warn">
    Terraform needs one hand-written <strong>aliased</strong> block per region.
    OpenTofu-only since <strong>1.9</strong>.
  </KwCard>
  </div>
</div>

<!--
Say: This is the first feature you can't write in Terraform. In Terraform, a
provider block can be aliased but not looped — to cover N regions you hand-write N
aliased blocks and keep them in sync by copy-paste. OpenTofu 1.9 lets a provider
block take for_each, so one declaration produces one instance per key, addressable
as alias-bracket-key. A resource then selects its instance with provider equals
alias-bracket-each-dot-key. Drive both from the same region set and the keys line
up automatically; adding a region becomes a one-line edit that fans out the whole
config. The lab applies exactly this against LocalStack. (~4 min)
Then: "Its companion from the same release — a surgical plan filter."
-->

---
layout: two-cols-code
heading: '-exclude (1.9) — plan everything but one address'
---

```console
# Apply everything EXCEPT one leaf:
$ tofu apply -exclude='aws_s3_object.marker["eu-west-1"]'
Plan: 3 to add, 0 to change, 0 to destroy.

# Exclude a DEPENDENCY → its dependents go too:
$ tofu plan -exclude='aws_s3_bucket.regional["eu-west-1"]'
  # aws_s3_bucket.regional["us-east-1"] will be created
Plan: 1 to add, 0 to change, 0 to destroy.
```

::right::

<div class="mt-2">
  <KwCard heading="The inverse of -target" kind="state" variant="accent">
    <code>-target</code> keeps only what you name; <code>-exclude</code> keeps
    everything <em>but</em> what you name. Often the shorter list.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="Dependents come along" kind="state" variant="warn">
    Excluding an address also excludes <strong>everything downstream</strong> of
    it — you can't keep a resource while dropping what it needs.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="Recovery tool, not routine" kind="validation" variant="danger">
    Both print a <em>targeting is in effect</em> warning. For breaking a bad
    apply out of a jam — not day-to-day workflow.
  </KwCard>
  </div>
</div>

<!--
Say: The 1.9 companion is -exclude, the inverse of -target. Where -target keeps
only the addresses you name, -exclude keeps everything except them — and when the
thing you want to skip is a small slice of a big config, the exclude list is far
shorter. The critical behavior, which the lab makes you see: -exclude also drops
everything downstream of what you exclude. Exclude a leaf and only that leaf goes;
exclude a bucket and its dependent object goes with it — you cannot keep a
resource while removing what it depends on. Both -target and -exclude are recovery
tools that print a targeting-in-effect warning; they're for getting out of a jam,
not routine applies. (~4 min)
Then: "One more timeline entry worth calling out for platform teams — OCI."
-->

---

<span class="kw-kicker">1.10 · for platform teams</span>

# OCI registries — mirror providers *and* modules

<div class="kw-cols-2 mt-4">
  <KwCard heading="Reuse what you already run" kind="state" variant="ok">
    Since <strong>1.10</strong>, OpenTofu can pull <strong>providers and
    modules</strong> from an <strong>OCI</strong> registry — the same container
    registry your org already operates. No bespoke mirror to stand up.
  </KwCard>
  <KwCard heading="Air-gapped &amp; regulated" kind="module" variant="accent">
    A first-class answer for environments that can't reach a public registry:
    vendor artifacts into an internal OCI registry and pull from there.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

You met filesystem/network mirroring and this OCI story earlier, with modules —
here it's just one node on the differentiator timeline. A version constraint still
resolves the same way; you've only changed *where* the artifacts come from.

</div>

<!--
Say: The last differentiator to flag is aimed at platform and security teams. As
of 1.10, OpenTofu can distribute providers AND modules through an OCI registry —
the same container registry your organization already runs — so you don't stand up
a bespoke mirror. For air-gapped or regulated environments that can't reach a
public registry, that's a first-class supply-chain answer: vendor your artifacts
into an internal OCI registry and pull from there. You saw this in the modules
work already, so here it's just one node on the timeline — and the click makes the
through-line explicit: your version constraints resolve exactly as before, you've
only changed where the artifacts come from. (~3 min)
Then: "Now go run the 1.9 pair for real — Lab 10."
-->

---
layout: lab
lab: labs/day-1/10-differentiators.md
duration: 25 min
env: 'localstack ✓'
---

# Lab 10 — provider `for_each` & `-exclude` on LocalStack

Bring up LocalStack, fan **one** `provider "aws"` block over two regions with
`for_each`, and apply **one S3 bucket per region** — `4 added`, each in its own
region. Then wield `-exclude`: drop a leaf (clean), drop a dependency (its
dependents follow). Finally trigger the real **`Provider instance not present`**
error by shrinking the region set with resources still live, and fix it.

Every task has a `<details>` spoiler; panic reset is `task lab:down`.

<!--
Say: Set up the lab and its payoff. You'll start LocalStack, then fan a single AWS
provider block over us-east-1 and eu-west-1 with for_each, and apply one S3 bucket
per region — four resources, and tofu state show proves each bucket landed in its
own region. Then you'll exercise -exclude both ways: excluding a leaf drops just
it, excluding a bucket drops its dependent object too. The break-fix is the real
provider-for_each gotcha: shrink the shared region set while resources are still
in state and you get Provider-instance-not-present; the fix is to re-add the
element. All against LocalStack, zero cloud cost. Every task has a spoiler; panic
reset is task lab:down. (~25 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: OpenTofu differentiators — recap
story: 'OpenTofu has diverged from Terraform on features — here are the ones you reach for.'
next: 'Next: Best practices — structure, lifecycle & refactoring'
---

- OpenTofu is drop-in **compatible** with Terraform HCL *and* has **diverged on
  features** since 1.7 — several with no Terraform equivalent.
- **Client-side state & plan encryption** (1.7) is the flagship — you already
  built it; this section points back to it rather than re-teaching.
- **Provider `for_each`** (1.9): one `provider` block → one instance per key;
  a resource selects its instance with `provider = alias[each.key]`.
- **`-exclude`** (1.9): the inverse of `-target` — plan everything *but* an
  address **and its dependents**; a recovery tool, not routine.
- **OCI registries** (1.10) mirror providers *and* modules through the container
  registry you already run — for air-gapped and regulated orgs.

<!--
Say: Pull the threads together. OpenTofu stays drop-in compatible with Terraform
HCL, but since 1.7 the feature sets have diverged, and several OpenTofu features
have no Terraform equivalent. The flagship is client-side state and plan
encryption from 1.7, which you built earlier — we referenced it, not re-taught it.
The two you ran today are both 1.9: provider for_each, where one provider block
becomes one instance per key and resources select with provider-equals-alias-
bracket-key; and -exclude, the inverse of -target that plans everything but an
address and its dependents, a recovery tool rather than routine. And for platform
teams, 1.10's OCI registries mirror providers and modules through the registry you
already run. Call forward: next we turn to best practices — structure, lifecycle,
and refactoring. (~2 min)
Then: transition into Best practices.
-->
