# Lab 07 — Modules: extract once, consume twice (S07)

| | |
| --- | --- |
| **Section** | S07 — Modules & the registry *(red line: author → parameterize → guard → **package**)* |
| **Environment** | `mock ✓ (no docker)` — pure-local `local` + `random` providers; no cloud, no LocalStack, no registry network for the runnable path |
| **Estimated time** | 35 min |

## Objective

In S06 you gave the config a typed interface; in S15 you guarded it. Now you
**package** it. You take the manifest resource you have been carrying forward and
extract it into a **local module** with its own input and output contract — then
consume that one module **twice**, with **different inputs**, and watch **both**
instances apply as distinct addresses (`module.checkout` / `module.payments`).

The payoff is the **break → fix**: you introduce a **version-constraint mismatch**
a provider can't satisfy, run `tofu init`, read the real resolver error line by
line, then revert the constraint and re-init clean. You run **tracked files**, not
heredocs — what you apply is exactly what CI verified. The config lives at
`labs/day-1/07-modules/`:

- `main.tf` — the **root** module. It declares two `module "…"` blocks that call
  the same local module with different `service` inputs, and re-exports each
  instance's outputs.
- `modules/service-manifest/` — the **child** module: `variables.tf` (input
  contract), `main.tf` (the extracted `local_file` + `random_pet`), `outputs.tf`
  (output contract). This is the reusable unit.

> **Scope note (no-Docker, per the Day-1 chain):** the runnable module here is a
> **local** module (`source = "./modules/…"`) — no registry network, no OCI. The
> **OpenTofu registry** and **OCI mirroring (1.10)** are taught on the slides as
> concepts; this lab exercises composition + version constraints locally. A local
> module cannot itself carry a `version` argument (that is registry-only), so the
> break→fix uses a **provider** version constraint the resolver can't satisfy —
> the same "no available releases match" failure you would hit on a real module or
> provider pin. The prose calls this out where it matters.

## Prerequisites

- `tofu` ≥ 1.6 — modules, local sources, and version constraints are all long-GA.
  This lab was verified on `tofu v1.12.3` (`tofu version`).
- You have done Lab 06 (S06) and Lab 15 (S15) — this lab extracts the same
  `service`-driven manifest into a module.
- Run everything **from the repo clone** — no Docker, no cloud. `tofu init` for
  the break→fix step does reach the provider registry once to resolve versions.

## Files used

All tracked in `labs/day-1/07-modules/` — you run them, you do not paste them.

The **child module** is the reusable unit. Its input contract (`variables.tf`):

<!-- source: labs/day-1/07-modules/modules/service-manifest/variables.tf -->
```hcl
# The module's INPUT contract. A caller passes these; nothing else leaks in.
variable "service" {
  description = "The service this module renders a manifest for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}

variable "environment" {
  description = "Deployment environment recorded in the rendered manifest."
  type        = string
  default     = "dev"
}
```

Its body (`main.tf`) — the resource extracted straight from S15, now parameterized
by the module's variables:

<!-- source: labs/day-1/07-modules/modules/service-manifest/main.tf -->
```hcl
# Providers a module needs are declared in the module, inherited from the caller.
terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# The manifest resource extracted from S15 — one file per service. Because the
# filename derives from var.service.name, two callers with different names write
# two different files and never collide.
resource "random_pet" "release" {
  length = 2
}

resource "local_file" "manifest" {
  filename = "${path.root}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    RELEASE=${random_pet.release.id}
  EOT
}
```

Its output contract (`outputs.tf`) — what a caller may read:

<!-- source: labs/day-1/07-modules/modules/service-manifest/outputs.tf -->
```hcl
# The module's OUTPUT contract. A caller reads these; the resources stay private.
output "manifest_path" {
  description = "Where this instance's rendered manifest landed."
  value       = local_file.manifest.filename
}

output "release" {
  description = "The generated release name for this instance."
  value       = random_pet.release.id
}
```

The **root** module (`main.tf`) consumes that one module **twice**:

<!-- source: labs/day-1/07-modules/main.tf -->
```hcl
terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# First instance: consume the LOCAL module with the checkout service's inputs.
module "checkout" {
  source = "./modules/service-manifest"

  service = {
    name     = "checkout"
    tier     = "standard"
    replicas = 2
  }
  environment = "staging"
}

# Second instance: the SAME module, different inputs. Because service.name
# differs, this writes a separate file and applies alongside the first.
module "payments" {
  source = "./modules/service-manifest"

  service = {
    name     = "payments"
    tier     = "critical"
    replicas = 4
  }
  environment = "prod"
}

# Read each instance's outputs — the module's public contract.
output "checkout_manifest" {
  description = "Path to the checkout instance's rendered manifest."
  value       = module.checkout.manifest_path
}

output "payments_manifest" {
  description = "Path to the payments instance's rendered manifest."
  value       = module.payments.manifest_path
}
```

> The `random_pet` release names and `local_file` IDs in the outputs below are
> from one real run on `tofu v1.12.3` — yours will differ in those volatile bits.
> The structure (two module addresses, two files, 4 resources) is what to match.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/07-modules
ls -R
```

**Task:** Confirm the root and child module files are already present — you author
nothing.

<details><summary>Solution / expected output</summary>

```console
$ ls -R
.:
main.tf  modules

./modules:
service-manifest

./modules/service-manifest:
main.tf  outputs.tf  variables.tf
```

The root `main.tf` calls the child module at `modules/service-manifest/`.
(`.gitignore` is present too but hidden by `ls`.)
</details>

---

## Step 1 — `init` wires up the modules

```bash
tofu init
```

Unlike previous labs, `tofu init` now has **modules** to initialize before it even
looks at providers. Watch the `Initializing modules...` phase list **both**
instances pointing at the same source.

**Task:** How many module instances does `init` report, and where do they point?

<details><summary>Solution / expected output</summary>

```console
$ tofu init

Initializing the backend...
Initializing modules...
- checkout in modules/service-manifest
- payments in modules/service-manifest

Initializing provider plugins...
- Finding latest version of hashicorp/local...
- Finding latest version of hashicorp/random...
- Installing hashicorp/random v3.9.0...
- Installing hashicorp/local v2.9.0...
...
OpenTofu has been successfully initialized!
```

Two instances — `checkout` and `payments` — **both resolve to the same source**,
`modules/service-manifest`. That is the whole point of a module: define the shape
once, instantiate it many times. Providers are still resolved once, at the root.
</details>

---

## Step 2 — Consume the module twice: both instances apply

```bash
tofu apply -auto-approve
```

Each `module` block is a separate **instance** with its own resource addresses
(`module.checkout.*`, `module.payments.*`). Because each renders a file named after
its `service.name`, the two never collide.

**Task:** How many resources are added? What are the two module addresses, and do
the two rendered files differ?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
module.payments.random_pet.release: Creating...
module.checkout.random_pet.release: Creating...
module.checkout.random_pet.release: Creation complete after 0s [id=lucky-heron]
module.payments.random_pet.release: Creation complete after 0s [id=brave-bat]
module.payments.local_file.manifest: Creating...
module.checkout.local_file.manifest: Creating...
module.payments.local_file.manifest: Creation complete after 0s [id=f1a5dc819be04f4b90f44efff900b6e9e141b0a1]
module.checkout.local_file.manifest: Creation complete after 0s [id=c1eca66696a109ccd205a45b7479fdf1d9890f80]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

checkout_manifest = "./out/checkout.env"
payments_manifest = "./out/payments.env"
```

**4 resources** — two per instance (a `random_pet` and a `local_file`). The
addresses are namespaced by the module: `module.checkout.*` and
`module.payments.*`. Confirm the two files differ:

```console
$ cat out/checkout.env
SERVICE_NAME=checkout
SERVICE_TIER=standard
REPLICAS=2
ENVIRONMENT=staging
RELEASE=lucky-heron

$ cat out/payments.env
SERVICE_NAME=payments
SERVICE_TIER=critical
REPLICAS=4
ENVIRONMENT=prod
RELEASE=brave-bat
```

One module definition, two instances, two distinct results — driven entirely by
the different **inputs** each caller passed.
</details>

---

## Step 3 — Break: a version constraint the resolver can't satisfy

Version constraints are how you pin *what* a module or provider resolves to. Here
you'll trip one on purpose. A **local** module (`source = "./…"`) can't take a
`version` — that's registry-only — so we pin a **provider** to an impossible
version instead; the resolver error is the same class you'd hit pinning a real
registry module or provider.

Open `modules/service-manifest/main.tf` and change the `local` provider line to
demand a version that does not exist:

```hcl
# EDIT (temporarily) — in modules/service-manifest/main.tf:
local  = { source = "hashicorp/local", version = ">= 99.0.0" }
```

Then re-init so the resolver runs again:

```bash
tofu init
```

**Task:** At which command does this fail — `init`, `plan`, or `apply`? Read the
error: what exactly can't be resolved?

<details><summary>Solution / expected output</summary>

```console
$ tofu init

Initializing the backend...
Initializing modules...

Initializing provider plugins...
- Finding latest version of hashicorp/random...
- Finding hashicorp/local versions matching ">= 99.0.0"...
- Installing hashicorp/random v3.9.0...
- Installed hashicorp/random v3.9.0 (signed, key ID 0C0AF313E5FD9F80)
...
╷
│ Error: Failed to resolve provider packages
│ 
│ Could not resolve provider hashicorp/local: no available releases match the
│ given constraints >= 99.0.0
╵
```

It fails at **`init`** — the phase that resolves modules and providers, *before*
any plan. Read it top to bottom:

1. `Finding hashicorp/local versions matching ">= 99.0.0"` — the resolver honoured
   your constraint and went looking.
2. `Error: Failed to resolve provider packages` — it could not find a match.
3. `no available releases match the given constraints >= 99.0.0` — the exact
   reason: no published `hashicorp/local` release satisfies `>= 99.0.0`.

This is the same failure mode as pinning a **module** to a version its registry
doesn't publish — a version constraint is a hard gate resolved at `init`, so a bad
pin stops you before you ever plan.
</details>

---

## Step 4 — Fix: revert the constraint and re-init clean

The config is fine; only the impossible pin is wrong. Revert that one line back to
the tracked form (no `version`), then re-init:

```hcl
# Restore in modules/service-manifest/main.tf:
local  = { source = "hashicorp/local" }
```

```bash
tofu init
```

**Task:** Confirm `init` succeeds again. What did the fix actually change?

<details><summary>Solution / expected output</summary>

```console
$ tofu init
...
OpenTofu has been successfully initialized!

You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure.
```

Dropping the impossible `>= 99.0.0` pin lets the resolver pick the latest published
`hashicorp/local` again, so `init` completes. Nothing about the *composition*
changed — the break was purely a version-constraint mismatch, and the fix was to
remove the unsatisfiable constraint. `git diff` should now show **no changes** to
the tracked files.
</details>

## Expected observations

- A **module** is defined once (`modules/service-manifest/`) and **instantiated
  many times** — here twice, as `module.checkout` and `module.payments`.
- Each instance is driven entirely by its **inputs**; distinct inputs
  (`service.name`) produce distinct results (two files) that apply side by side —
  `Apply complete! Resources: 4 added`.
- `tofu init` initializes **modules first**, then providers; a module instance is
  named in the `Initializing modules...` list.
- A **version constraint** is resolved at **`init`**. An unsatisfiable pin fails
  with `no available releases match the given constraints` — before any plan. The
  fix is to correct or remove the pin; the composition is untouched.

## Cleanup / panic reset

Destroy the (local-only) resources and remove every generated artifact — no
residue, `git status` clean:

```bash
cd labs/day-1/07-modules
tofu destroy -auto-approve                                   # tear down both instances' local_file + random_pet
rm -rf .terraform .terraform.lock.hcl out
find . -maxdepth 1 -name 'terraform.tfstate*' -delete        # sweep any state/backup files safely
git status --short .                                          # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state / `.terraform` / rendered `out/` files are gitignored; the
panic reset leaves the tracked files exactly as CI verified them.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.
> If you edited `modules/service-manifest/main.tf` in Step 3, `git checkout --
> modules/service-manifest/main.tf` restores it (Step 4's revert should already
> have).

## Stretch (optional)

- **Consume with `for_each`.** Replace the two hand-written `module` blocks with a
  single `module "service"` using `for_each` over a `map` of service objects.
  Instances become `module.service["checkout"]` / `module.service["payments"]` —
  the same two files, half the HCL. When is `for_each` clearer than named blocks?
- **Add an input `validation`.** Move S06's replica rule *into* the child module's
  `variable "service"` so every caller inherits the guard. A module can carry its
  own validation, preconditions, and checks — the packaging includes the contract.
- **Pin to a real registry module.** On a networked machine, add a public registry
  module (e.g. a well-known `null`/`random` wrapper) with a `version = "~> x.y"`
  constraint and run `tofu init` — see the registry resolve a *real* version,
  contrasting the local `source = "./…"` path you used here.
