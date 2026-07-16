---
layout: section-cover
image: /covers/section-00-arrival.png
day: Day 1
section: '00'
tier: core
---

# Welcome & setup

Three days from "what is a resource" to a tested, encrypted, orchestrated
multi-module project — with no cloud bill.

<!--
Say: Open with energy — welcome the room and set the arc. Over three days we go
from "what is a resource" to a tested, encrypted, orchestrated multi-module
project, and we do it all locally with no cloud bill. Reassure anyone new to IaC
that the ramp is gentle and roughly half the time is hands-on. (~2 min)
Then: "Here's the red line that ties all three days together" — into what you'll
build.
-->

---

<span class="kw-kicker">The red line</span>

# What you'll build

<div class="kw-cols-3 mt-4">
  <KwCard heading="Part 1 · Author" kind="resource">
    <strong>Write it.</strong> HCL, state, modules, best practices — culminating
    in a tested naming + labelling module with encrypted state.
  </KwCard>
  <KwCard heading="Part 2 · Test" kind="test">
    <strong>Trust it.</strong> Static analysis, policy scanners, native
    <code>tofu test</code>, and mocking — the IaC testing pyramid.
  </KwCard>
  <KwCard heading="Part 3 · Scale" kind="stack" variant="plain">
    <strong>Grow it.</strong> Terramate — stacks, code generation, orchestration,
    and change detection across a monorepo.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Every block ends with a hands-on lab — roughly half the workshop is your hands
on the keyboard. Labs run on **LocalStack**, so you never need an AWS account.

</div>

<!--
Say: This is the red line — Author, Test, Scale — and every section maps onto it.
Part 1 you write it (HCL, state, modules) and it culminates in a tested naming and
labelling module with encrypted state. Part 2 you learn to trust it (static
analysis, policy scanners, native tofu test, mocking — the IaC testing pyramid).
Part 3 you grow it with Terramate — stacks, codegen, orchestration. Land the click
reveal: every block ends in a lab, ~50% hands-on, all on LocalStack. (~3 min)
Then: "Before the labs, two ground rules about what we're actually teaching."
-->

---
layout: statement
kicker: 'Ground rules'
---

We teach **OpenTofu** and the `tofu` CLI. The HCL language is shared with
Terraform — everything you learn transfers — but the runtime is open source,
and some features here exist **only** in OpenTofu.

<!--
Say: Set expectations clearly. We use OpenTofu and type tofu at every prompt. The
HCL you learn is the shared language, so everything transfers to Terraform — but
the runtime is open source, and a few headline features (state encryption is the
one they'll remember) exist only in OpenTofu. We don't run a parallel Terraform
track; we note compatibility as we go. (~2 min)
Then: "So what do you actually need installed? Five tools."
-->

---

<span class="kw-kicker">Toolchain</span>

# The five tools

<div class="kw-cols-2 mt-4">
  <KwCard heading="tofu ≥ 1.8" icon="🧊">
    The OpenTofu CLI. Everything runs through <code>tofu init / plan / apply</code>.
  </KwCard>
  <KwCard heading="Docker + LocalStack" icon="🐳">
    An AWS emulator on <code>:4566</code>. Real resource types, zero cloud bill.
  </KwCard>
  <KwCard heading="Task (go-task)" icon="✅">
    One entrypoint: <code>task setup</code>, <code>task lab:up</code>, <code>task verify</code>.
  </KwCard>
  <KwCard heading="gum + your editor" icon="🎛️">
    A friendly interactive setup and lab runner, plus an HCL-aware editor.
  </KwCard>
</div>

<div v-click class="mt-5 kw-muted text-sm">

Run <code>task setup</code> — it detects what's missing and walks you through it.

</div>

<!--
Say: Walk the four cards. tofu (>= 1.8) is the CLI everything runs through. Docker
plus LocalStack gives an AWS emulator on :4566 — real resource types, zero bill.
Task (go-task) is the single entrypoint: setup, lab:up, verify. gum plus their
editor is the friendly runner. Land the reveal: nobody hand-installs — task setup
detects what's missing and walks them through it. (~2 min)
Then: "Let's prove the whole loop works — first contact, plan then apply."
-->

---
layout: code-walkthrough
heading: First contact — plan then apply
lab: labs/day-1/00-setup.md
---

````md magic-move
```console
$ tofu init
Initializing the backend...
Initializing provider plugins...
OpenTofu has been successfully initialized!
```

```console
$ tofu plan
OpenTofu will perform the following actions:

  # local_file.hello will be created
  + resource "local_file" "hello" {
      + content  = "hello, opentofu"
      + filename = "./hello.txt"
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

```console
$ tofu apply -auto-approve
local_file.hello: Creating...
local_file.hello: Creation complete after 0s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```
````

<!--
Say: This is the core loop in three magic-move steps. init sets up the backend and
downloads providers. plan shows what WILL happen — a local_file to be created —
and changes nothing. apply -auto-approve makes it real. Hammer the mental model:
plan is a preview, apply is the commit; nothing touches the world until you apply.
We use local_file so the very first apply needs no cloud at all. (~3 min)
Then: "Your turn — Lab 00 gets this running on your machine."
-->

---
layout: lab
lab: labs/day-1/00-setup.md
duration: 20 min
env: 'localstack ✓ · mock ✓'
---

# Lab 00 — set up & first apply

Install the toolchain with `task setup`, run your first `local_file` apply, then
bring up LocalStack and create your first `aws_s3_bucket` — proof the whole loop
works before we go deep.

<!--
Say: Kick off the first lab and set the goal: install with task setup, do the
local_file apply, then bring up LocalStack and create a real aws_s3_bucket against
the :4566 emulator — proof the full loop works before we go deep. Circulate; the
common snag is Docker not running. Panic reset is always task lab:down. (~20 min,
matches the lab duration)
Then: regroup and recap what we've established.
-->

---
layout: recap
heading: Welcome — recap
story: 'You have a working, cloud-free OpenTofu lab. Now we learn what the code means.'
next: 'Next: Infrastructure as Code — and why OpenTofu exists'
---

- The workshop's red line: **author → test → scale**, ~50% hands-on.
- We use **OpenTofu** (`tofu`); HCL is shared with Terraform.
- Labs run on **LocalStack** + `mock_provider` — no cloud account, no bill.
- `task setup` / `task lab:up` / `task verify` are the only commands you memorise.

<!--
Say: Close the loop — they now have a working, cloud-free OpenTofu lab and have
seen the whole plan/apply flow once. Recap the four anchors: the author-test-scale
red line, tofu with shared HCL, LocalStack plus mock_provider so there's no bill,
and the three commands they memorise. (~2 min)
Then: transition into Infrastructure as Code — and why OpenTofu exists — "now we
learn what the code actually means."
-->

