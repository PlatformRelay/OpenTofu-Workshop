---
layout: section-cover
image: /covers/placeholder-section.svg
day: Day 1
section: '00'
tier: core
---

# Welcome & setup

Three days from "what is a resource" to a tested, encrypted, orchestrated
multi-module project — with no cloud bill.

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

---
layout: statement
kicker: 'Ground rules'
---

We teach **OpenTofu** and the `tofu` CLI. The HCL language is shared with
Terraform — everything you learn transfers — but the runtime is open source,
and some features here exist **only** in OpenTofu.

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
