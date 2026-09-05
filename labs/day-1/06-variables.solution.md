# Lab 06 — Parameterize with typed, validated variables (S06) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/06-variables/` unless a step says otherwise.

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/06-variables
ls
```

**Task:** Confirm the config files are already present — you author nothing.

---

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf  terraform.tfvars
```

`main.tf` and `terraform.tfvars` are tracked in the repo. Everything below runs
against these exact files. (`.gitignore` is present too but hidden by `ls`.)

</details>

---

### Step 1 — Init and apply (values come from `terraform.tfvars`)

```bash
tofu init
tofu apply -auto-approve
```

`terraform.tfvars` is auto-loaded, so no flags are needed: `environment` resolves
to `staging` and `service` to the checkout object.

**Task:** Apply, then note the two things the output reveals — the winning
`environment` and how the sensitive token prints.

---

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

### Step 2 — Prove precedence: `-var` overrides `terraform.tfvars`

The stack, weakest → strongest: `default` < `TF_VAR_*` < `terraform.tfvars` <
`*.auto.tfvars` < `-var`. `terraform.tfvars` already beat the default in Step 1.
Now push a stronger source and watch it win:

```bash
tofu apply -auto-approve \
  -var='environment=prod' \
  -var='service={name="checkout",tier="standard",replicas=2}'
```

**Task:** Which value does `effective_environment` show now, and why?

---

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

### Step 3 — Break the cross-variable `validation` (on purpose)

The `service` variable's rule reads **another** variable: a `prod` service must
have at least 2 replicas. Feed it a `prod` environment with a single replica and
watch it fail **before** any resource is planned:

```bash
tofu plan \
  -var='environment=prod' \
  -var='service={name="checkout",tier="standard",replicas=1}'
```

**Task:** What error do you get, and what makes it a *cross-variable* diagnostic?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='environment=prod' \
    -var='service={name="checkout",tier="standard",replicas=1}'
Error: Invalid value for variable

  on main.tf line 16:
  16: variable "service" {
    ├────────────────
    │ var.environment is "prod"
    │ var.service.replicas is 1

A prod service needs at least 2 replicas (got 1).

This was checked by the validation rule at main.tf:27,3-13.
```

The diagnostic prints **both** `var.environment` and `var.service.replicas` —
proof the rule reasoned across two variables, not just its own value. That
cross-variable reference is the OpenTofu 1.9 feature. (Pre-1.9 engines reject the
config outright with *"Invalid reference in variable validation"*.)

</details>

---

### Step 4 — Fix it

Two valid fixes: give `prod` enough replicas, or drop the environment. Prove the
rule now passes:

```bash
tofu plan \
  -var='environment=prod' \
  -var='service={name="checkout",tier="standard",replicas=2}'
```

**Task:** Confirm the plan succeeds once the rule is satisfied.

---

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

### Step 5 — Trip the single-variable rule too

The `environment` variable has its own simpler rule (an allow-list). Feed it a
value outside the list:

```bash
tofu plan -var='environment=production'
```

**Task:** What does the allow-list rule report?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='environment=production'
Error: Invalid value for variable

  on main.tf line 33:
  33: variable "environment" {
    ├────────────────
    │ var.environment is "production"

environment must be one of: dev, staging, prod.

This was checked by the validation rule at main.tf:38,3-13.
```

`"production"` isn't in `["dev", "staging", "prod"]`, so `contains(...)` is false
and the plan stops with your message. This one references only its own variable —
the classic, pre-1.9 style of validation.

</details>

---

### Step 6 — Unmask the sensitive output (deliberately)

`sensitive` masks a value everywhere it would print. To read it you must ask
explicitly. First re-run Step 1's plain apply so state is back to the `staging`
baseline, then:

```bash
tofu output              # full output: api_token stays masked
tofu output -raw api_token   # explicit unmask
```

**Task:** Show that the full output masks the token but `-raw` reveals it.

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

---

## Expected state / output

- `terraform.tfvars` values beat variable **defaults**; a CLI `-var` beats
  `terraform.tfvars` — the precedence stack in action.
- A **cross-variable** `validation` (OpenTofu 1.9) fails with a diagnostic naming
  *both* variables it read (`var.environment` and `var.service.replicas`).
- A single-variable rule (the `environment` allow-list) is the classic pre-1.9
  style — it references only its own value.
- A `sensitive` variable/output prints as `<sensitive>` and must be unmasked on
  purpose with `tofu output -raw` — masking is display-only, not encryption.

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

Re-enter `labs/day-1/06-variables/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- Add a `list(string)` variable (e.g. `allowed_cidrs`) and a `validation` that
- Split `service` into loose variables (`service_name`, `service_tier`, …) and
- Move the `service` value into a `*.auto.tfvars` file and confirm it still beats

---

Example verification from the workdir:

```bash
cd labs/day-1/06-variables
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
