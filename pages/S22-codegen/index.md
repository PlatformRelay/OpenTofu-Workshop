---
layout: section-cover
image: /covers/section-22-the-pattern-loom.webp
day: Day 3
section: '22'
tier: core
---

# Code generation

## One blueprint — many stacks stay DRY

<!--
Say: S21 gave you discoverable stacks. Look at the leaves — backend.tf and providers.tf were still copy-pasted byte-for-byte. Today Terramate writes that boilerplate from one definition so every stack stays in sync. Generate is the second verb of Day 3. (~1 min)
Then: Name the two generation primitives.
-->

---
layout: statement
kicker: 'Generate · DRY'
---

Hand-written backends and providers **rot between stacks**.

`generate_hcl` / `generate_file` + **globals** turn one blueprint into the
same files in every leaf — evaluated once, committed everywhere.

<!--
Say: Modules reuse logic inside a root. Codegen reuses the root itself — the terraform backend block, the required_providers map, the provider stanza. Globals are the shared dials; generate blocks are the templates. (~2 min)
Then: Put the accent on generate in the four-phase loop.
-->

---
clicks: 4
---

<span class="kw-kicker">orchestration · generate</span>

# Four phases — today is generate

<TerramateOrchestration phase="generate" :step="$clicks" class="mt-8" />

<div v-click="4" class="mt-8 kw-muted text-sm text-center">

Discover is done (<strong>S21</strong>). Order and filter come in <strong>S23</strong>–<strong>S24</strong>.

</div>

<!--
Say: Same four-phase loop. Discover is done. Generate is lit. Order and filter stay for later. (~2 min)
Then: Contrast the two generate block kinds.
-->

---
layout: comparison
leftHeading: generate_hcl
leftBadge: HCL → .tf
rightHeading: generate_file
rightBadge: any text
---

<span class="kw-kicker">primitives</span>

# Two ways to emit files

::left::

```hcl
generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "local" {
        path = global.backend_path
      }
    }
  }
}
```

HCL-aware. Globals / metadata evaluate;
OpenTofu blocks stay valid HCL.

::right::

```hcl
generate_file "README.md" {
  content = tm_format(
    "# %s\n",
    terramate.stack.name,
  )
}
```

Arbitrary text — docs, ignore
rules, non-HCL configs.

<!--
Say: generate_hcl is the workhorse for backend and provider boilerplate — partial evaluation fills globals, the rest ships as HCL. generate_file is the escape hatch for plain text. Today's lab stays on generate_hcl. (~3 min)
Then: Where do the dial values live?
-->

---
layout: two-cols-code
heading: Globals inherit down the tree
---

````md magic-move
```hcl
# Root — shared dials for every stack
globals {
  backend_path = "terraform.tfstate"
}
```

```hcl
# Root
globals {
  terraform_version      = ">= 1.8"
  local_provider_version = "~> 2.5"
  backend_path           = "terraform.tfstate"
}
```

```hcl
# Root globals.tm.hcl
globals {
  terraform_version      = ">= 1.8"
  local_provider_version = "~> 2.5"
  backend_path           = "terraform.tfstate"
}

# Optional leaf override — stacks/app/globals.tm.hcl
globals {
  backend_path = "app.tfstate"
}
```
````

::right::

<div class="mt-2">
  <KwCard heading="Root globals" kind="module" variant="accent">
    Defined once near <code>terramate.tm.hcl</code>. Every child stack sees them.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="Leaf override" kind="state" variant="plain">
    A stack may redefine a key — closer wins. Inheritance is hierarchical, not copy-paste.
  </KwCard>
  </div>
  <div class="mt-3">
  <KwCard heading="Reference" kind="validation" variant="ok">
    Inside <code>generate_hcl</code>, read with <code>global.&lt;name&gt;</code>.
  </KwCard>
  </div>
</div>

<!--
Say: Globals flow root → leaf. The lab ships root dials only so both stacks emit the same backend path. A leaf globals.tm.hcl can override one key when a stack truly differs — that is inheritance, not a second copy of the generate block. (~3 min)
Then: Watch the blueprint become a file.
-->

---
layout: code-walkthrough
heading: From globals to `_backend.tf`
---

````md magic-move
```hcl
globals {
  backend_path = "terraform.tfstate"
}
```

```hcl
globals {
  backend_path = "terraform.tfstate"
}

generate_hcl "_backend.tf" {
  content {
  }
}
```

```hcl
globals {
  backend_path = "terraform.tfstate"
}

generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "local" {
        path = global.backend_path
      }
    }
  }
}
```

```hcl
// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```
````

<p class="mt-4 text-sm opacity-75">
OpenTofu loads <code>.tf</code> only in the stack root — generate <code>_backend.tf</code> beside
<code>main.tf</code> (S20's <code>_gen/*.tf</code> sketch meant shared HCL, not a nested dir tofu ignores).
</p>

<!--
Say: Frame by frame: dials, then an empty generate_hcl labelled with the output filename, then the content block that references global.backend_path, then what terramate generate actually writes — including the DO NOT EDIT banner. The leading underscore marks generated files in the leaf. (~4 min)
Then: Point at the tracked lab artifacts.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · root globals</span>

# One set of dials

<!-- source: labs/day-3/22-codegen/globals.tm.hcl -->
```hcl {1|2-3|4|1-5}
globals {
  terraform_version      = ">= 1.8"
  local_provider_version = "~> 2.5"
  backend_path           = "terraform.tfstate"
}
```

::notes::

<CodeNote at="1" label="Block">Root <code>globals</code> — inherited by every stack under this monorepo.</CodeNote>
<CodeNote at="2" label="Versions">OpenTofu and provider pins — change once, regenerate everywhere.</CodeNote>
<CodeNote at="3" label="Backend">Local state path for the mock lab — swap for a remote backend in real work.</CodeNote>
<CodeNote at="4" label="File">Lives beside <code>terramate.tm.hcl</code> / generate blueprints.</CodeNote>

<!--
Say: This is the tracked globals file. Three dials. Slides and lab share this source. (~2 min)
Then: The generate_hcl that consumes them.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · backend blueprint</span>

# `generate_hcl "_backend.tf"`

<!-- source: labs/day-3/22-codegen/backend.tm.hcl -->
```hcl {1|2-8|4-6|1-9}
generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "local" {
        path = global.backend_path
      }
    }
  }
}
```

::notes::

<CodeNote at="1" label="Label">Output filename relative to each stack directory.</CodeNote>
<CodeNote at="2" label="Content">HCL template — not yet evaluated.</CodeNote>
<CodeNote at="3" label="Global"> <code>global.backend_path</code> resolves at generate time.</CodeNote>
<CodeNote at="4" label="Emit"> <code>terramate generate</code> writes this into every discovered stack.</CodeNote>

<!--
Say: Label is the path inside the stack. Content is the HCL template. global.backend_path is evaluated when you generate — not when tofu runs. (~2 min)
Then: Show the emitted file both stacks share.
-->

---
layout: code-annotated
---

<span class="kw-kicker">taught artifact · generated backend</span>

# Emitted `_backend.tf`

<!-- source: labs/day-3/22-codegen/stacks/network/_backend.tf -->
```hcl {1|3-7|1-8}
// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

::notes::

<CodeNote at="1" label="Banner">Hand-edits here are wrong — fix the blueprint, then regenerate.</CodeNote>
<CodeNote at="2" label="Evaluated">The path is a concrete string — globals already resolved.</CodeNote>
<CodeNote at="3" label="Identical"> <code>stacks/app/_backend.tf</code> matches byte-for-byte until a leaf overrides globals.</CodeNote>

<!--
Say: The banner is the contract. If a learner patches this file, the next generate rewrites it. Stale or hand-edited generated files are today's break→fix. (~2 min)
Then: Providers follow the same pattern — glance, then lab.
-->

---
layout: two-cols-code
heading: Providers — same pattern
---

<!-- source: labs/day-3/22-codegen/providers.tm.hcl -->
```hcl
generate_hcl "_providers.tf" {
  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        local = {
          source  = "hashicorp/local"
          version = global.local_provider_version
        }
      }
    }

    provider "local" {}
  }
}
```

::right::

<!-- source: labs/day-3/22-codegen/stacks/network/_providers.tf -->
```hcl
// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = ">= 1.8"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
provider "local" {
}
```

<!--
Say: Left is the blueprint; right is what generate writes. Formatting may normalise braces — trust the tracked file. Leaves keep only main.tf as hand-authored OpenTofu. (~2 min)
Then: Hands-on — delete generated files, regenerate, then break a stale file.
-->

---
layout: lab
lab: labs/day-3/22-codegen.md
duration: 30 min
env: 'mock ✓ (no docker)'
---

# Lab — generate backends & providers

- Extend the S21 stacks with root globals + `generate_hcl`.
- `terramate generate` for all stacks; leaves keep only `main.tf`.
- Break→fix: stale generated file → regenerate.

<!--
Say: Mock only — no Docker. Learners copy the workdir, strip generated _*.tf, run generate, confirm both stacks match, then corrupt one file and watch generate restore it. Spoilers match terramate 0.17.x. (~30 min)
Then: Debrief — blueprints + globals beat copy-paste.
-->

---
layout: recap
next: S23 · Orchestration
---

<span class="kw-kicker">recap · generate</span>

# Code generation — operating rules

- **Globals** inherit down the tree; leaves may override a key.
- **`generate_hcl`** emits OpenTofu HCL; **`generate_file`** emits any text.
- Run **`terramate generate`** after blueprint or global changes — commit the result.
- Hand-editing generated files is a bug; regenerate is the fix.

<p v-click class="mt-8 text-xl font-semibold">One blueprint, many stacks — generate, don't copy-paste.</p>

<!--
Say: Close on DRY. Next, S23 orders runs across these stacks with after/before so network can land before app. (~2 min)
Then: S23 · Orchestration.
-->
