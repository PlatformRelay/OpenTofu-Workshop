# Lab 06 — Parameterize with typed, validated variables (S06)

| | |
| --- | --- |
| **Section** | S06 — Variables, validation & types *(red line: author → **parameterize** → validate)* |
| **Environment** | `mock ✓ (no docker)` — pure-local `local` + `random` providers; no cloud, no LocalStack |
| **Estimated time** | 25 min |

## Objective

Take a config with typed inputs and turn its knobs into a proper interface:
a typed `object` variable, a `sensitive` token, and outputs. Then **break a
cross-variable `validation` on purpose**, read the real diagnostic, and fix it.
Along the way, prove the **precedence stack** — a `terraform.tfvars` value
overridden by `-var` — and watch a `sensitive` output print as `<sensitive>`.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/06-variables/`:

- `main.tf` — the whole config: a typed `service` object variable with a
  cross-variable `validation`, an `environment` variable with its own rule, a
  `sensitive` `api_token`, a `random_password`, a `local_file` the object drives,
  and three outputs. This is the exact HCL the lab applies; the slide and this
  file are drift-checked to stay byte-identical.
- `terraform.tfvars` — auto-loaded values (`environment = "staging"`, the
  `service` object). The `.tfvars` tier of the precedence stack.

## Prerequisites

- `tofu` ≥ 1.9 (`task setup` installs it). Cross-variable validation needs 1.9+.
  Check: `tofu version`.
- `jq` is optional here (not required by any step).
- Run everything **from the repo clone** — no Docker, no cloud.

## Files used

All tracked in `labs/day-1/06-variables/` — you run them, you do not paste them:

- `main.tf` — variables, resources, and outputs (below).
- `terraform.tfvars` — the auto-loaded values used for the precedence demo.
- `.gitignore` — keeps generated state / `.terraform` / the rendered `out/` file
  out of version control.

This is the config you apply — read it before you run it:

<!-- source: labs/day-1/06-variables/main.tf -->
```hcl
terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# A typed object variable: one value, several fields, each with its own type.
variable "service" {
  description = "The service this config provisions a credential file for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })

  # Cross-variable validation (OpenTofu 1.9+): the condition reads BOTH this
  # variable and var.environment. A rule can now reason about the whole config,
  # not just its own value.
  validation {
    condition     = !(var.environment == "prod" && var.service.replicas < 2)
    error_message = "A prod service needs at least 2 replicas (got ${var.service.replicas})."
  }
}

variable "environment" {
  description = "Deployment environment. Drives the prod replica rule above."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# A sensitive variable never prints its value in plan/apply/output.
variable "api_token" {
  description = "A secret the service authenticates with. Marked sensitive."
  type        = string
  sensitive   = true
  default     = "dev-placeholder-token"
}

# A generated secret — the kind of value that lands in state (see S05).
resource "random_password" "session" {
  length = 20
}

# The object variable drives a real file: types in, artifact out.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    API_TOKEN=${var.api_token}
    SESSION_SECRET=${random_password.session.result}
  EOT
}

output "manifest_path" {
  description = "Where the rendered credential file landed."
  value       = local_file.manifest.filename
}

# Echoes the winning environment value so the precedence stack is visible in
# `tofu output` without opening the rendered file.
output "effective_environment" {
  description = "Whichever source won for var.environment (default < tfvars < -var)."
  value       = var.environment
}

# A sensitive output surfaces as <sensitive> unless explicitly unmasked.
output "api_token" {
  description = "Echoes the token — but sensitive, so it prints as <sensitive>."
  value       = var.api_token
  sensitive   = true
}
```

> Provider versions and generated IDs/secrets in the outputs below are from one
> real run on `tofu v1.12.3` — yours will differ in those volatile bits.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/06-variables
ls
```

**Task:** Confirm the config files are already present — you author nothing.

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf  terraform.tfvars
```

`main.tf` and `terraform.tfvars` are tracked in the repo. Everything below runs
against these exact files. (`.gitignore` is present too but hidden by `ls`.)
</details>

---

## Step 1 — Init and apply (values come from `terraform.tfvars`)

```bash
tofu init
tofu apply -auto-approve
```

`terraform.tfvars` is auto-loaded, so no flags are needed: `environment` resolves
to `staging` and `service` to the checkout object.

**Task:** Apply, then note the two things the output reveals — the winning
`environment` and how the sensitive token prints.

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
Plan: 2 to add, 0 to change, 0 to destroy.
Changes to Outputs:
  + api_token             = (sensitive value)
  + effective_environment = "staging"
  + manifest_path         = "./out/checkout.env"
random_password.session: Creating...
random_password.session: Creation complete after 0s [id=none]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=3382d21dded6...]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

api_token = <sensitive>
effective_environment = "staging"
manifest_path = "./out/checkout.env"
```

`effective_environment = "staging"` comes from `terraform.tfvars` (it beat the
`"dev"` default), and `api_token` prints as `<sensitive>`, never the value.
</details>

---

## Step 2 — Prove precedence: `-var` overrides `terraform.tfvars`

The stack, weakest → strongest: `default` < `TF_VAR_*` < `terraform.tfvars` <
`*.auto.tfvars` < `-var`. `terraform.tfvars` already beat the default in Step 1.
Now push a stronger source and watch it win:

```bash
tofu apply -auto-approve \
  -var='environment=prod' \
  -var='service={name="checkout",tier="standard",replicas=2}'
```

**Task:** Which value does `effective_environment` show now, and why?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve -var='environment=prod' \
    -var='service={name="checkout",tier="standard",replicas=2}'
...
  ~ effective_environment = "staging" -> "prod"
...
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

Outputs:

api_token = <sensitive>
effective_environment = "prod"
manifest_path = "./out/checkout.env"
```

`-var` sits at the **top** of the stack, so `prod` overrides the `staging` from
`terraform.tfvars`. (A `TF_VAR_environment=…` env var would have lost to the
`.tfvars` file — try it: `TF_VAR_environment=dev tofu apply -auto-approve` still
resolves to `staging`.) Leave state at this `prod`/`replicas=2` baseline — Steps
3–5 only *plan*, so they won't change it, and Step 6 resets to `staging`.
</details>

---

## Step 3 — Break the cross-variable `validation` (on purpose)

The `service` variable's rule reads **another** variable: a `prod` service must
have at least 2 replicas. Feed it a `prod` environment with a single replica and
watch it fail **before** any resource is planned:

```bash
tofu plan \
  -var='environment=prod' \
  -var='service={name="checkout",tier="standard",replicas=1}'
```

**Task:** What error do you get, and what makes it a *cross-variable* diagnostic?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='environment=prod' \
    -var='service={name="checkout",tier="standard",replicas=1}'
Error: Invalid value for variable

  on main.tf line 9:
   9: variable "service" {
    ├────────────────
    │ var.environment is "prod"
    │ var.service.replicas is 1

A prod service needs at least 2 replicas (got 1).

This was checked by the validation rule at main.tf:20,3-13.
```

The diagnostic prints **both** `var.environment` and `var.service.replicas` —
proof the rule reasoned across two variables, not just its own value. That
cross-variable reference is the OpenTofu 1.9 feature. (Pre-1.9 engines reject the
config outright with *"Invalid reference in variable validation"*.)
</details>

---

## Step 4 — Fix it

Two valid fixes: give `prod` enough replicas, or drop the environment. Prove the
rule now passes:

```bash
tofu plan \
  -var='environment=prod' \
  -var='service={name="checkout",tier="standard",replicas=2}'
```

**Task:** Confirm the plan succeeds once the rule is satisfied.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='environment=prod' \
    -var='service={name="checkout",tier="standard",replicas=2}'
No changes. Your infrastructure matches the configuration.
```

Bumping `replicas` to 2 satisfies `!(prod && replicas < 2)`, so the plan runs
clean. (The state already matches from Step 2, hence "No changes".)
</details>

---

## Step 5 — Trip the single-variable rule too

The `environment` variable has its own simpler rule (an allow-list). Feed it a
value outside the list:

```bash
tofu plan -var='environment=production'
```

**Task:** What does the allow-list rule report?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='environment=production'
Error: Invalid value for variable

  on main.tf line 26:
  26: variable "environment" {
    ├────────────────
    │ var.environment is "production"

environment must be one of: dev, staging, prod.

This was checked by the validation rule at main.tf:31,3-13.
```

`"production"` isn't in `["dev", "staging", "prod"]`, so `contains(...)` is false
and the plan stops with your message. This one references only its own variable —
the classic, pre-1.9 style of validation.
</details>

---

## Step 6 — Unmask the sensitive output (deliberately)

`sensitive` masks a value everywhere it would print. To read it you must ask
explicitly. First re-run Step 1's plain apply so state is back to the `staging`
baseline, then:

```bash
tofu output              # full output: api_token stays masked
tofu output -raw api_token   # explicit unmask
```

**Task:** Show that the full output masks the token but `-raw` reveals it.

<details><summary>Solution / expected output</summary>

```console
$ tofu output
api_token = <sensitive>
effective_environment = "staging"
manifest_path = "./out/checkout.env"

$ tofu output -raw api_token
dev-placeholder-token
```

`tofu output` (and every plan/apply summary) masks a `sensitive` value as
`<sensitive>`. `tofu output -raw NAME` is the deliberate opt-out — you unmask only
when you mean to. Remember: masking is **display-only**; the token is still
plaintext in state (that's what S05's state encryption is for).
</details>

## Expected observations

- `terraform.tfvars` values beat variable **defaults**; a CLI `-var` beats
  `terraform.tfvars` — the precedence stack in action.
- A **cross-variable** `validation` (OpenTofu 1.9) fails with a diagnostic naming
  *both* variables it read (`var.environment` and `var.service.replicas`).
- A single-variable rule (the `environment` allow-list) is the classic pre-1.9
  style — it references only its own value.
- A `sensitive` variable/output prints as `<sensitive>` and must be unmasked on
  purpose with `tofu output -raw` — masking is display-only, not encryption.

## Cleanup / panic reset

Destroy the (local-only) resources and remove every generated artifact — no
residue, `git status` clean:

```bash
cd labs/day-1/06-variables
tofu destroy -auto-approve                                   # tear down local_file + random_password
rm -rf .terraform .terraform.lock.hcl out
find . -maxdepth 1 -name 'terraform.tfstate*' -delete        # sweep any state/backup files safely
git status --short .                                          # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state / `.terraform` / rendered `out/` file are gitignored; the
panic reset leaves the tracked files exactly as CI verified them.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.

## Stretch (optional)

- Add a `list(string)` variable (e.g. `allowed_cidrs`) and a `validation` that
  every element matches a CIDR shape — practise a collection type plus a rule.
- Split `service` into loose variables (`service_name`, `service_tier`, …) and
  feel the difference: more inputs, no single shape to validate as a whole. Then
  put it back as an `object` — that's the recommended form.
- Move the `service` value into a `*.auto.tfvars` file and confirm it still beats
  the default but still loses to `-var`.

---

**Next:** [Lab 15 — Preconditions, postconditions & check blocks](15-conditions-checks.md)
carries this `service` module forward and layers native assertions onto it — a
`precondition` and an output precondition at plan, a `postcondition` that breaks on
apply, and a non-blocking `check` block.
