---
layout: section-cover
image: /covers/section-07-the-parts-depot.png
day: Day 1
section: '07'
tier: core
---

# Modules & the registry

You have written, typed, and guarded a config. The next move is **reuse**:
package it once as a module, then instantiate it many times. Meet composition,
sources, version constraints, the OpenTofu registry, and OCI mirroring.

<!--
Say: Frame the section as the packaging step of the Day-1 red line — you authored
HCL (S02–S03), gave it a typed interface (S06), and guarded it (S15); now you make
it reusable. A module is just a directory of HCL with an input and output
contract, and the payoff is instantiating one definition many times. This section
covers the four things you need to use modules well: composition, where a module
comes from (its source), how you pin its version, and OpenTofu's own registry and
mirroring story for regulated and air-gapped orgs. (~1 min)
Then: "Start with the smallest true statement — you already have a module."
-->

---
layout: statement
kicker: 'The reframe'
---

Every config is **already a module** — the root module.

A "module" is just a **directory of HCL** you call from another with `module {}`,
passing **inputs** and reading **outputs**.

<!--
Say: Land the reframe that demystifies modules. There is nothing special about a
module — the directory you have been running in every lab IS a module, the root
module. A reusable module is the same thing: a directory of .tf files. The only
new mechanics are the module block that calls it, the input variables you pass in,
and the outputs you read back. If you can write a variable and an output, you can
write a module. (~2 min)
Then: "So composition is just root modules calling child modules — here's the
shape."
-->

---

<span class="kw-kicker">Composition</span>

# Root calls child, passes inputs, reads outputs

<div class="kw-cols-2 mt-4">
  <KwCard heading="The child module" kind="module">
    A directory of HCL with a <strong>contract</strong>: <code>variable</code>
    blocks in, <code>output</code> blocks out. Its resources stay <strong>private</strong>.
  </KwCard>
  <KwCard heading="The root module" kind="module" variant="ok">
    Calls the child with <code>module "name" {}</code>, sets its inputs, and reads
    <code>module.name.output</code>. Instantiate it <strong>many times</strong>.
  </KwCard>
</div>

<div v-click class="mt-4 kw-muted text-sm">

Each `module` block is a distinct **instance** with namespaced addresses —
`module.checkout.local_file.manifest`, `module.payments.local_file.manifest`.
Same definition, different inputs, independent state.

</div>

<!--
Say: This is the composition model. A child module exposes a contract — variables
are its inputs, outputs are what it publishes; everything else, the resources, is
an implementation detail the caller never touches. The root module calls it with a
module block, wires its inputs, and reads its outputs by the module-dot-name-dot-
output path. The click drives home the reuse payoff: each module block is its own
instance with namespaced resource addresses, so calling the same module twice with
different inputs gives you two independent sets of resources with independent
state. That is exactly what the lab does. (~3 min)
Then: "Where does that child module come from? That's the source argument."
-->

---
layout: two-cols-code
heading: Sources — where a module comes from
---

```hcl
# Local path — a directory in this repo. No network, no version.
module "checkout" {
  source = "./modules/service-manifest"
}

# Git — any reachable repo, optionally pinned to a ref.
module "vpc" {
  source = "git::https://example.com/net.git//vpc?ref=v1.4.0"
}

# Registry — NAMESPACE/NAME/PROVIDER, versionable.
module "label" {
  source  = "app.terraform.io/acme/label/aws"
  version = "~> 1.2"
}
```

::right::

<div class="mt-2">
  <KwCard heading="Local ./…" kind="module" variant="ok">
    In-repo directory. <strong>No <code>version</code></strong> — it's whatever is
    on disk. This lab's path.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="Git" kind="module">
    Any repo; pin with <code>?ref=</code> (tag/branch/SHA). Version comes from the
    ref, not a <code>version</code> arg.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="Registry" kind="module" variant="warn">
    <code>NS/NAME/PROVIDER</code>; the <strong>only</strong> source that takes a
    <code>version</code> constraint.
  </KwCard>
  </div>
</div>

<!--
Say: A module's source argument decides where it comes from, and the source type
determines how you version it. A local path is an in-repo directory — no network,
and crucially no version argument, because it's simply whatever HCL sits on disk;
that's the path the lab uses. A Git source is any reachable repo, and you pin it
with a ref query parameter — a tag, branch, or commit — so the version lives in
the ref, not a version field. Only a registry source, addressed as
namespace-slash-name-slash-provider, accepts a version constraint. Flag that
asymmetry now, because it's exactly what the lab's break-fix hinges on. (~4 min)
Then: "Let's look at version constraints, the one that only registry sources get."
-->

---

<span class="kw-kicker">Version constraints</span>

# Pin what resolves — at `init`

<div class="kw-cols-2 mt-4">
  <KwCard heading="The operators" kind="module">
    <code>= 1.4.0</code> exact · <code>>= 1.2</code> floor ·
    <code>~> 1.2</code> pessimistic (allows 1.x, not 2.0) · ranges combine.
  </KwCard>
  <KwCard heading="When it resolves" kind="state" variant="warn">
    At <strong><code>tofu init</code></strong> — the phase that fetches modules and
    providers. An unsatisfiable pin fails <strong>here</strong>, before any plan.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

The same constraint syntax pins **providers** (`required_providers { … version }`)
and **registry modules** (`module { … version }`). A pin the registry can't
satisfy fails at init — the resolver reports *"no available releases match the
given constraints"*. The lab drives exactly this break→fix.

</div>

<!--
Say: Version constraints are how you control what actually resolves. The operators
are worth knowing cold: equals is exact, greater-than-or-equal is a floor, and the
pessimistic squiggle-arrow allows patch and minor bumps but never the next major —
the safe default for most pins. The key insight is the phase: constraints resolve
at init, the step that fetches modules and providers, so a bad pin fails at init
before you ever reach plan. The click makes the connection to the lab: the same
syntax pins providers and registry modules, and pinning something with no matching
release produces the exact resolver error you'll trigger and read — no available
releases match the given constraints. (~4 min)
Then: "Those registry pins point at a registry — and OpenTofu's is its own story."
-->

---

<span class="kw-kicker">The OpenTofu registry</span>

# Decentralized, GitHub-backed, no click-through

<div class="kw-cols-2 mt-4">
  <KwCard heading="How it works" kind="module" variant="ok">
    An index at <code>registry.opentofu.org</code> mapping
    <code>NS/NAME</code> → a GitHub repo. Binaries pull from GitHub releases;
    checksums + signatures verified.
  </KwCard>
  <KwCard heading="How you contribute" kind="module">
    Submission is a <strong>GitHub PR/issue</strong> — no click-through license,
    no gatekeeper. OpenTofu also rebuilds HashiCorp's MPL-era providers.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

The governance contrast to the HashiCorp registry: decentralized, open, and
Linux-Foundation-governed. Same constraint/versioning mechanics you just saw — a
different trust and contribution model underneath.

</div>

<!--
Say: The registry your pins point at matters, and OpenTofu's is deliberately
different. It's a decentralized, GitHub-backed index: an entry maps a
namespace-and-name to a GitHub repository, and provider binaries are pulled
straight from GitHub releases with checksums and signatures verified. Contributing
is just opening a GitHub PR or issue — there's no click-through license and no
central gatekeeper, and OpenTofu additionally rebuilds HashiCorp's MPL-era
providers under the hashicorp namespace so existing configs keep working. The
click names the contrast: same versioning mechanics you just learned, but a
decentralized, Linux-Foundation-governed trust model instead of a single vendor's.
(~3 min)
Then: "And when you can't reach any registry at all — mirroring, including OCI."
-->

---
layout: two-cols-code
heading: Mirroring & OCI — for air-gapped and regulated orgs
---

```bash
# Package every provider this config needs into a local mirror directory:
tofu providers mirror ./vendor/providers

# Point tofu at the mirror instead of the network (CLI config / env):
#   provider_installation {
#     filesystem_mirror { path = "./vendor/providers" }
#   }
```

::right::

<div class="mt-2">
  <KwCard heading="Filesystem / network mirror" kind="state">
    <code>tofu providers mirror DIR</code> vendors providers to a directory, or
    serve them from an internal mirror server. Air-gap-friendly.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="OCI registry mirrors (1.10)" kind="state" variant="ok">
    Since <strong>1.10</strong>, mirror providers <strong>and modules</strong>
    through an <strong>OCI</strong> registry — reuse the container registry you
    already run.
  </KwCard>
  </div>
</div>

<div v-click class="mt-3 text-sm kw-muted">

The through-line: a version constraint still resolves the same way — you've only
changed *where* the artifacts come from.

</div>

<!--
Say: The last beat is for regulated and air-gapped environments that can't reach a
public registry. The classic answer is a mirror: tofu providers mirror packages
every provider a config needs into a local directory, and you point tofu at that
filesystem mirror, or an internal network mirror server, instead of the internet.
The 1.10 addition is the headline for platform teams — you can now mirror providers
and modules through an OCI registry, meaning you reuse the same container registry
your org already operates rather than standing up bespoke infrastructure. The click
ties it back: mirroring only changes where artifacts come from; your version
constraints resolve exactly as before. (~3 min)
Then: "Now go extract a module and consume it twice — Lab 07."
-->

---
layout: lab
lab: labs/day-1/07-modules.md
duration: 35 min
env: 'mock ✓ (no docker)'
---

# Lab 07 — extract a module, consume it twice

Take the S15 manifest resource, extract it into a **local module** with an input
and output contract, then call that one module **twice** with different inputs —
watch both `module.checkout` and `module.payments` apply as `4 added`. Then
introduce a **version-constraint mismatch**, read the real `tofu init` resolver
error line-by-line, and fix it.

Every task has a `<details>` spoiler; panic reset leaves the tree clean.

<!--
Say: Set up the lab and its payoff. You'll take the manifest resource you carried
through S06 and S15 and extract it into a local child module with its own
variables and outputs, then instantiate that one module twice — a checkout service
and a payments service — with different inputs, and confirm both apply as distinct
namespaced addresses, four resources total. Then the break-fix: because a local
module can't carry a version, you pin a provider to an impossible version, run
init, and read the genuine no-available-releases resolver error, then revert. No
Docker, pure local providers. Every task has a spoiler; panic reset leaves the tree
clean. (~35 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Modules & the registry — recap
story: 'Package config once as a module, instantiate it many times, and pin what resolves.'
next: 'Next: Naming & labelling module'
---

- A **module** is a directory of HCL with a contract: `variable` inputs,
  `output` outputs; the **root** module calls it with `module {}`.
- **Instantiate many times** — each `module` block is a distinct instance with
  namespaced addresses (`module.checkout.*`, `module.payments.*`).
- **Sources:** local `./…` (no version), Git (`?ref=`), and registry
  (`NS/NAME/PROVIDER` — the only source that takes a `version`).
- **Version constraints** resolve at **`tofu init`** (the lock is checked first);
  an unsatisfiable pin fails with *"no available releases match the given
  constraints"* — before any plan.
- The **OpenTofu registry** is decentralized + GitHub-backed; **mirroring** —
  filesystem/network and **OCI (1.10)** — covers air-gapped orgs.

<!--
Say: Pull the threads together. A module is nothing more than a directory of HCL
with a contract — variable inputs and output outputs — and the root module calls
it with a module block. The reuse payoff is instantiating one definition many
times, each a distinct instance with namespaced addresses. Sources decide origin
and versioning: local paths carry no version, Git pins via ref, and only registry
sources take a version constraint. Those constraints resolve at init, so a bad pin
fails before plan with no-available-releases — the error you read in the lab. And
OpenTofu's registry is decentralized and GitHub-backed, with filesystem, network,
and since 1.10 OCI mirroring for air-gapped orgs. Call forward: next we build the
flagship naming and labelling module that puts all of this to work. (~2 min)
Then: transition into the Naming & labelling module.
-->
