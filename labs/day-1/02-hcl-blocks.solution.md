# Lab 02 — HCL & the building blocks — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/02-hcl-blocks/` unless a step says otherwise.

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/02-hcl-blocks
ls
```

**Task:** Confirm the config is already present — you author nothing (until the
break→fix, where you add one scratch file).

---

<details><summary>Solution / expected output</summary>

```console
$ ls
greeting  main.tf  motd.txt
```

`main.tf`, the `greeting/` module, and `motd.txt` are all tracked. Everything
below runs against these exact files. (`.gitignore` is present too; `ls` hides
dotfiles by default.)

</details>

---

### Step 1 — Read the config, block by block

`cat main.tf` and read it top to bottom. It is deliberately small but uses **every
core block type** exactly once so you can see each one in context:

<!-- source: labs/day-1/02-hcl-blocks/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# provider — configures a plugin. `local` needs no settings; the block still
# declares that this config uses it.
provider "local" {}

# variable — a typed input. Override it with -var, a *.tfvars file, or an
# environment variable; here it defaults so the lab runs with zero flags.
variable "owner" {
  type        = string
  description = "Name recorded as the owner of the generated artifacts."
  default     = "workshop"
}

# locals — named expressions computed once and reused. Keeps interpolation
# out of the resources below.
locals {
  banner   = upper(var.owner)
  out_file = "${path.module}/build/summary.txt"
}

# data — reads something that already exists (here a tracked file on disk)
# without managing it. Its result is available as data.local_file.motd.content.
data "local_file" "motd" {
  filename = "${path.module}/motd.txt"
}

# resource — a thing OpenTofu creates, updates, and destroys. random_pet
# generates a stable identity once and stores it in state.
resource "random_pet" "id" {
  length = 2
}

# module — calls reusable config in ./greeting, passing an input and reading
# an output back. This is how you compose configurations.
module "greeting" {
  source = "./greeting"
  name   = local.banner
}

# resource — the file OpenTofu owns. Its content references the variable, the
# local, the data source, the random_pet resource, and the module output —
# every reference kind in one place.
resource "local_file" "summary" {
  filename = local.out_file
  content  = <<-EOT
    owner   = ${var.owner} (${local.banner})
    id      = ${random_pet.id.id}
    motd    = ${trimspace(data.local_file.motd.content)}
    greeting= ${module.greeting.message}
  EOT
}

# output — a value surfaced after apply and consumable by other configs.
output "summary_path" {
  description = "Where the generated summary landed."
  value       = local_file.summary.filename
}
```

**Task:** Name the block type behind each of these, and say whether it *creates*
anything: `terraform`, `provider "local"`, `variable "owner"`, `locals`,
`data "local_file" "motd"`, `resource "random_pet" "id"`, `module "greeting"`,
`output "summary_path"`.

---

<details><summary>Solution</summary>

| Block | Type | Creates anything? |
| --- | --- | --- |
| `terraform { … }` | settings block — version + provider requirements | no |
| `provider "local" {}` | **provider** — plugin config | no |
| `variable "owner"` | **variable** — typed input | no |
| `locals { … }` | **locals** — computed named values | no |
| `data "local_file" "motd"` | **data** — reads an existing thing | no (read-only) |
| `resource "random_pet" "id"` | **resource** — managed object | **yes** |
| `module "greeting"` | **module** — calls reusable config | via its own resources (none here) |
| `output "summary_path"` | **output** — surfaced value | no |

Only **`resource`** blocks (and resources inside modules) create, change, or
destroy real objects. Everything else configures, computes, reads, or reports.
Note the top-level block is still named `terraform {}` for HCL compatibility even
though you run the `tofu` CLI.

</details>

---

### Step 2 — Syntax: blocks, arguments, expressions

Every line in that file is one of three things. Look again and classify them.

**Task:** In `resource "local_file" "summary" { … }`, which part is the **block
header**, which lines are **arguments**, and where is an **expression**?

---

<details><summary>Solution</summary>

```hcl
resource "local_file" "summary" {   # block header: TYPE + two LABELS + { }
  filename = local.out_file          # argument: name = expression
  content  = <<-EOT                  # argument whose expression is a heredoc
    ...
  EOT
}
```

- **Block** = a header (`resource "local_file" "summary"`) plus a `{ … }` body.
  The words after the type are **labels** (here the provider type and your local
  name).
- **Argument** = `name = value` inside a body (`filename = …`).
- **Expression** = the value side — a literal, a reference (`local.out_file`), a
  function call (`upper(var.owner)`), or an interpolation (`"${…}"`). That is the
  whole grammar; every config is blocks of arguments whose values are expressions.

</details>

---

### Step 3 — `init` and `plan`: watch the references resolve

```bash
tofu init
tofu plan
```

**Task:** How many resources will be created, and what does `plan` read *before*
it plans?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu init

Initializing the backend...
Initializing modules...
- greeting in greeting

Initializing provider plugins...
- Installing hashicorp/local v2.9.0...
- Installing hashicorp/random v3.9.0...
...
OpenTofu has been successfully initialized!
```

```console
$ tofu plan
data.local_file.motd: Reading...
data.local_file.motd: Read complete after 0s [id=814df8902c4ba19647d2062068385706580f0ea7]
...
Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + summary_path = "./build/summary.txt"
```

`init` also **initializes the module** (`- greeting in greeting`). `plan` shows
`Plan: 2 to add` — the `random_pet` and the `local_file` (a `data` source *reads*
but never counts as an add; the module here declares no resources of its own).
The `data.local_file.motd` line is OpenTofu **reading the tracked `motd.txt`
first**, because `local_file.summary` references it. (Provider versions may differ
as the registry moves; the count of 2 is what matters.)

</details>

---

### Step 4 — `apply` and read the wired-together result

```bash
tofu apply -auto-approve
cat build/summary.txt
```

**Task:** Every line of `summary.txt` comes from a *different* block. Match each
line to the reference that produced it.

---

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
random_pet.id: Creation complete after 0s [id=pleased-javelin]
local_file.summary: Creation complete after 0s [id=9a783a972b46adaeebdf23f4b19d0961ae014e7b]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

summary_path = "./build/summary.txt"

$ cat build/summary.txt
owner   = workshop (WORKSHOP)
id      = pleased-javelin
motd    = Welcome to the OpenTofu workshop.
greeting= Hello, WORKSHOP!
```

- `owner = workshop` → `var.owner` (the **variable** default).
- `(WORKSHOP)` → `local.banner`, i.e. `upper(var.owner)` (the **local**).
- `id = pleased-javelin` → `random_pet.id.id` (the **resource** — yours will
  differ; it is generated once and stored in state).
- `motd = Welcome…` → `data.local_file.motd.content` (the **data** source reading
  `motd.txt`).
- `greeting= Hello, WORKSHOP!` → `module.greeting.message` (the **module**
  output).

That single file is the entire dependency graph resolved: one `resource`
referencing a `variable`, a `local`, a `data` source, another `resource`, and a
`module` output.

</details>

---

### Step 5 — Break → fix: reference something you never declared

The most common HCL mistake is referencing a name that doesn't exist. Do it on
purpose in a **scratch** file (`broken.tf`) so `main.tf` stays pristine:

```bash
cat > broken.tf <<'EOF'
resource "local_file" "note" {
  filename = "${path.module}/build/note.txt"
  content  = "Maintained by ${var.maintainer}.\n"
}
EOF
tofu plan
```

**Task (break):** Why does `plan` fail — and what exactly does OpenTofu tell you to
do?

Now **fix** it — declare the variable it asked for and re-plan:

```bash
cat > broken.tf <<'EOF'
variable "maintainer" {
  type        = string
  description = "Name recorded on the note file."
  default     = "platform-team"
}

resource "local_file" "note" {
  filename = "${path.module}/build/note.txt"
  content  = "Maintained by ${var.maintainer}.\n"
}
EOF
tofu plan
```

## Expected observations

- One config uses **every core block type**: `terraform`, `provider`, `variable`,
  `locals`, `data`, `resource`, `module`, `output`.
- HCL is **blocks** (header + `{ }`), **arguments** (`name = value`), and
  **expressions** (literals, references, functions, `"${…}"` interpolation).
- **References wire the graph:** `var.*`, `local.*`, `data.*.*`, `<resource>.*`,
  and `module.*.*` all resolve at plan time.
- Only **`resource`** blocks create, change, or destroy real objects; the rest
  configure, compute, read, or report.
- A reference to an **undeclared** name fails `plan` with *"Reference to undeclared
  …"* — declaring the missing block fixes it. OpenTofu accepts both `.tf` and
  `.tofu` file extensions for these configs.

## Cleanup / panic reset

Destroy the (local-only) resources and remove all generated residue — no cloud
resources exist, so nothing to bill or leak:

```bash
cd labs/day-1/02-hcl-blocks
rm -f broken.tf
tofu destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* build
git status --short .      # expect: no output
```

## Stretch (optional)

- Add a second output that exposes `random_pet.id.id`, `apply`, and read it with
  `tofu output`.
- Rename `main.tf` to `main.tofu` and re-run `tofu plan` — OpenTofu accepts the
  `.tofu` extension identically. (Rename it back before committing.)
- Give the `greeting` module a second input (e.g. a `punctuation` variable) and
  thread it from `main.tf` — watch how module inputs and outputs compose.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan

Error: Reference to undeclared input variable

  on broken.tf line 3, in resource "local_file" "note":
   3:   content  = "Maintained by ${var.maintainer}.\n"

An input variable with the name "maintainer" has not been declared. This
variable can be declared with a variable "maintainer" {} block.
```

`broken.tf` references `var.maintainer`, but no `variable "maintainer"` block
exists. OpenTofu resolves references at plan time, finds nothing named
`maintainer`, and **refuses to plan** — it even names the fix: declare a
`variable "maintainer" {}` block. Nothing was created; a broken reference is a
config error, caught before any change.

</details>

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
random_pet.id: Refreshing state... [id=pleased-javelin]
data.local_file.motd: Read complete after 0s [id=814df8902c4ba19647d2062068385706580f0ea7]
local_file.summary: Refreshing state... [id=9a783a972b46adaeebdf23f4b19d0961ae014e7b]

OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

OpenTofu will perform the following actions:

  # local_file.note will be created
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

Declaring `variable "maintainer"` makes the reference resolvable, so `plan`
succeeds again: `Plan: 1 to add` (the new `note.txt`). **Every reference must
resolve to a declared block** — that is the rule the error was enforcing. You do
not need to `apply` this; the point was the break and the fix. Remove the scratch
file in cleanup.

</details>

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.summary: Destroying... [id=9a783a972b46adaeebdf23f4b19d0961ae014e7b]
local_file.summary: Destruction complete after 0s
random_pet.id: Destroying... [id=pleased-javelin]
random_pet.id: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

The generated state, `.terraform`, `build/`, and the scratch `broken.tf` are all
gitignored or removed; the panic reset leaves the tracked `main.tf`, `greeting/`,
and `motd.txt` exactly as CI verified them.

</details>

---

## Expected state / output

- One config uses **every core block type**: `terraform`, `provider`, `variable`,
  `locals`, `data`, `resource`, `module`, `output`.
- HCL is **blocks** (header + `{ }`), **arguments** (`name = value`), and
  **expressions** (literals, references, functions, `"${…}"` interpolation).
- **References wire the graph:** `var.*`, `local.*`, `data.*.*`, `<resource>.*`,
  and `module.*.*` all resolve at plan time.
- Only **`resource`** blocks create, change, or destroy real objects; the rest
  configure, compute, read, or report.
- A reference to an **undeclared** name fails `plan` with *"Reference to undeclared
  …"* — declaring the missing block fixes it. OpenTofu accepts both `.tf` and
  `.tofu` file extensions for these configs.

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

Destroy the (local-only) resources and remove all generated residue — no cloud
resources exist, so nothing to bill or leak:

```bash
cd labs/day-1/02-hcl-blocks
rm -f broken.tf
tofu destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* build
git status --short .      # expect: no output
```

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.summary: Destroying... [id=9a783a972b46adaeebdf23f4b19d0961ae014e7b]
local_file.summary: Destruction complete after 0s
random_pet.id: Destroying... [id=pleased-javelin]
random_pet.id: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

The generated state, `.terraform`, `build/`, and the scratch `broken.tf` are all
gitignored or removed; the panic reset leaves the tracked `main.tf`, `greeting/`,
and `motd.txt` exactly as CI verified them.
</details>

Re-enter `labs/day-1/02-hcl-blocks/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- Add a second output that exposes `random_pet.id.id`, `apply`, and read it with
- Rename `main.tf` to `main.tofu` and re-run `tofu plan` — OpenTofu accepts the
- Give the `greeting` module a second input (e.g. a `punctuation` variable) and

Example verification from the workdir:

```bash
cd labs/day-1/02-hcl-blocks
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
