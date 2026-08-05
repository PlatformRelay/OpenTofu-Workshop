# Lab 09 — count vs for_each, and refactor without replacement (S09) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/09-best-practices/` unless a step says otherwise.

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/09-best-practices
ls -a
```

**Task:** Confirm `main.tf` (and its `.gitignore`) are already present — you author
nothing; you only edit and revert.

---

<details><summary>Solution / expected output</summary>

```console
$ ls -a
.  ..  .gitignore  main.tf
```

`main.tf` is the `for_each` end state. `.gitignore` keeps generated
state / `.terraform` / the rendered `out/` directory out of version control.

</details>

---

### Step 1 — Start from `count`: apply three services

To see the trap you have to start where most configs start — a `count` fan-out.
**Temporarily** replace `main.tf` with the `count` form. Copy this whole block over
the file:

```hcl
# TEMPORARY (Step 1 starting point) — the count form, addressed by INDEX.
terraform {
  required_providers {
    local = { source = "hashicorp/local" }
  }
}

variable "services" {
  type = list(object({
    name     = string
    replicas = number
  }))
  default = [
    { name = "checkout", replicas = 2 },
    { name = "payments", replicas = 4 },
    { name = "search", replicas = 3 },
  ]
}

# count-based fan-out: instances are addressed by INDEX (manifest[0], [1], [2]).
resource "local_file" "manifest" {
  count = length(var.services)

  filename = "${path.module}/out/${var.services[count.index].name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.services[count.index].name}
    REPLICAS=${var.services[count.index].replicas}
  EOT
}
```

Then init and apply:

```bash
tofu init
tofu apply -auto-approve
tofu state list
```

**Task:** How many resources apply, and how are the three instances **addressed**
in state?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu init
...
- Installed hashicorp/local v2.9.0 (signed, key ID 0C0AF313E5FD9F80)
...
OpenTofu has been successfully initialized!

$ tofu apply -auto-approve
...
Plan: 3 to add, 0 to change, 0 to destroy.
...
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

$ tofu state list
local_file.manifest[0]
local_file.manifest[1]
local_file.manifest[2]
```

Three instances, **addressed by their list index**: `manifest[0]` is checkout,
`[1]` is payments, `[2]` is search. The index — a *position*, not an identity — is
the whole problem you are about to hit.

</details>

---

### Step 2 — The `count` trap: remove the middle element

A teammate deprecates the `payments` service and deletes its line. Under `count`,
deleting the **middle** entry doesn't just remove one instance — it renumbers every
entry after it. **Temporarily** delete the `payments` line from the `count` form's
`default` list so it reads:

```hcl
  default = [
    { name = "checkout", replicas = 2 },
    { name = "search", replicas = 3 },
  ]
```

Then plan — **do not apply**:

```bash
tofu plan
```

**Task:** You removed **one** service. How many resources does the plan destroy,
and *which* ones? Did the instance you actually removed even survive?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest[1] must be replaced
  # local_file.manifest[2] will be destroyed
  # (because index [2] is out of range for count)
...
Plan: 1 to add, 0 to change, 2 to destroy.
```

You removed **one** service but the plan is `1 to add, 0 to change, **2 to
destroy**`. Because indices shift, `manifest[1]` — formerly *payments* — is now
recomputed as *search* and **must be replaced** (its `filename` and `content`
change, and `local_file` is immutable), while `manifest[2]` is **destroyed** for
being out of range. The service you *kept*, `search`, gets churned; the index is a
position, not an identity. **Do not apply** — revert `payments` back into the list
first:

```hcl
  default = [
    { name = "checkout", replicas = 2 },
    { name = "payments", replicas = 4 },
    { name = "search", replicas = 3 },
  ]
```

```console
$ tofu apply -auto-approve
No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

</details>

---

### Step 3 — Refactor to `for_each` **without replacement** using `moved`

Now fix the design. Restore the tracked canonical `main.tf` — the `for_each` end
state with the three `moved` blocks:

```bash
git checkout -- main.tf
```

`for_each` addresses instances by a **stable key** (`manifest["payments"]`) instead
of a shifting index. But switching a resource from `count` to `for_each` normally
looks like a *different* resource to OpenTofu — the addresses changed
(`manifest[0]` → `manifest["checkout"]`) — so without help it would destroy all
three and recreate them. The three `moved` blocks tell OpenTofu that each old
address **is** the new one: rename in state, touch nothing real.

```bash
tofu plan
```

**Task:** The addresses all changed from index to key. How many resources does the
plan add, change, or destroy — and what does OpenTofu report instead?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest[0] has moved to local_file.manifest["checkout"]
  # local_file.manifest[1] has moved to local_file.manifest["payments"]
  # local_file.manifest[2] has moved to local_file.manifest["search"]
...
Plan: 0 to add, 0 to change, 0 to destroy.
```

**`0 to add, 0 to change, 0 to destroy`** — every instance is reported as
`has moved to`, a pure state rename. Nothing on disk is recreated. That is the
entire point of a `moved` block: it decouples "I renamed/re-keyed this in my code"
from "I want to rebuild this in the world."

Apply it to commit the state move:

```console
$ tofu apply -auto-approve
  # local_file.manifest[0] has moved to local_file.manifest["checkout"]
  # local_file.manifest[1] has moved to local_file.manifest["payments"]
  # local_file.manifest[2] has moved to local_file.manifest["search"]

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

$ tofu state list
local_file.manifest["checkout"]
local_file.manifest["payments"]
local_file.manifest["search"]
```

State is now **keyed by name**, and no file was rewritten.

</details>

---

### Step 4 — Prove the fix: remove the same middle element under `for_each`

Repeat Step 2's deletion, but on the keyed config. **Temporarily** delete the
`payments` line from the `default` map so it reads:

```hcl
  default = {
    checkout = { replicas = 2 }
    search   = { replicas = 3 }
  }
```

Then plan — **do not apply**:

```bash
tofu plan
```

**Task:** Same removal as Step 2. Compare the plan: how many are destroyed now, and
is `search` touched at all?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest["payments"] will be destroyed
  # (because key ["payments"] is not in for_each map)
...
Plan: 0 to add, 0 to change, 1 to destroy.
```

**`0 to add, 0 to change, 1 to destroy`** — only `manifest["payments"]`, keyed by
the name you removed, is destroyed. `checkout` and `search` are **not in the plan
at all**: their keys never moved, so their identity is stable. Compare with Step 2's
`1 to add, 2 to destroy` for the *identical* removal — that is the whole `count` vs
`for_each` decision in two plans.

Revert the deletion before moving on:

```hcl
  default = {
    checkout = { replicas = 2 }
    payments = { replicas = 4 }
    search   = { replicas = 3 }
  }
```

```console
$ tofu apply -auto-approve
No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

</details>

---

### Step 5 — Break → fix: an edit that silently forces a re-create

Not every replacement is as loud as deleting a resource. `local_file` is
**immutable**: change the *filename* and OpenTofu can't edit the file in place — it
must destroy the old one and create a new one. Say you "tidy up" the extension from
`.env` to `.conf`. **Temporarily** change that one line in `main.tf`:

```hcl
  filename = "${path.module}/out/${each.key}.conf"
```

Then plan — **do not apply**:

```bash
tofu plan
```

**Task:** You changed one word. What does the plan want to do to the **whole
fleet**, and which line does OpenTofu flag as the cause?

**Fix:** the change was cosmetic and not worth a fleet rebuild — revert it.

```bash
git checkout -- main.tf
tofu plan
```

## Expected observations

- **`count` addresses by index.** Removing a middle element renumbers every later
  instance; for an immutable resource that means `must be replaced` +
  `will be destroyed` — Step 2 removed one service and planned `2 to destroy`.
- **`for_each` addresses by key.** The identical removal touches only the removed
  key — Step 4 planned `1 to destroy`, and the surviving instances weren't in the
  plan at all. Prefer `for_each` whenever instances have a stable identity.
- **`moved` refactors state, not infrastructure.** Switching `count` → `for_each`
  with `moved` blocks planned `0 to add, 0 to change, 0 to destroy`, every instance
  reported `has moved to` — a state rename, nothing rebuilt.
- **`plan` is the safety gate.** A cosmetic `filename` edit planned `3 to destroy`
  with `# forces replacement` on the offending line — caught before apply. Read the
  action counts and the `forces replacement` annotations every time.

## Cleanup / panic reset

Destroy the (local-only) resources and remove every generated artifact — no
residue, `git status` clean:

```bash
cd labs/day-1/09-best-practices
tofu destroy -auto-approve                              # tear down the three local_file instances
git checkout -- main.tf                                 # undo any temporary Step 1-5 edits
rm -rf .terraform .terraform.lock.hcl out
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # sweep any state/backup files safely
git status --short .                                    # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state / `.terraform` / rendered `out/` files are gitignored; the
panic reset leaves the tracked `main.tf` exactly as CI verified it.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.
> `git checkout -- main.tf` is the belt-and-braces revert for the temporary edits
> in Steps 1, 2, 4, and 5.

## Stretch (optional)

- **`for_each` over the objects, not just keys.** The map values here carry only
  `replicas`. Add a `tier` field and reference `each.value.tier` in the manifest —
  see how `for_each`'s `each.value` gives you the whole object, where `count` gave
  you only an index into a separate list.
- **Chain two `moved` blocks.** Rename the resource *and* re-key it in one refactor
  (e.g. `local_file.manifest[0]` → `local_file.service_env["checkout"]`) and
  confirm the plan is still `0 to destroy`. `moved` blocks compose — a resource can
  travel several renames across releases and stay a single object in state.
- **Contrast with `removed`.** On the slides you saw the `removed` block: it drops a
  resource from state *without* destroying the real object (the safe successor to
  `state rm`). Reason about when you'd reach for `removed` versus simply deleting a
  `for_each` key — the difference is whether you want the underlying object gone or
  merely un-managed.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest["checkout"] must be replaced
      ~ filename             = "./out/checkout.env" -> "./out/checkout.conf" # forces replacement
  # local_file.manifest["payments"] must be replaced
      ~ filename             = "./out/payments.env" -> "./out/payments.conf" # forces replacement
  # local_file.manifest["search"] must be replaced
      ~ filename             = "./out/search.env" -> "./out/search.conf" # forces replacement
...
Plan: 3 to add, 0 to change, 3 to destroy.
```

`Plan: 3 to add, 0 to change, **3 to destroy**` — a one-word cosmetic change wants
to destroy and recreate **every** instance. OpenTofu tells you exactly why on the
changed line: **`# forces replacement`**. This is the everyday version of the trap:
the plan caught it before any file was deleted. Reading `plan` output — and never
`-auto-approve`-ing a surprise `must be replaced` / `forces replacement` — is the
practice this whole section is about.

</details>

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
No changes. Your infrastructure matches the configuration.
```

Reverting the extension restores `main.tf` to the tracked canonical form, and the
plan is a clean **`No changes`**. `git diff` now shows nothing — you end exactly
where CI verified.

</details>

---

## Expected state / output

- **`count` addresses by index.** Removing a middle element renumbers every later
  instance; for an immutable resource that means `must be replaced` +
  `will be destroyed` — Step 2 removed one service and planned `2 to destroy`.
- **`for_each` addresses by key.** The identical removal touches only the removed
  key — Step 4 planned `1 to destroy`, and the surviving instances weren't in the
  plan at all. Prefer `for_each` whenever instances have a stable identity.
- **`moved` refactors state, not infrastructure.** Switching `count` → `for_each`
  with `moved` blocks planned `0 to add, 0 to change, 0 to destroy`, every instance
  reported `has moved to` — a state rename, nothing rebuilt.
- **`plan` is the safety gate.** A cosmetic `filename` edit planned `3 to destroy`
  with `# forces replacement` on the offending line — caught before apply. Read the
  action counts and the `forces replacement` annotations every time.

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
cd labs/day-1/09-best-practices
tofu destroy -auto-approve                              # tear down the three local_file instances
git checkout -- main.tf                                 # undo any temporary Step 1-5 edits
rm -rf .terraform .terraform.lock.hcl out
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # sweep any state/backup files safely
git status --short .                                    # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state / `.terraform` / rendered `out/` files are gitignored; the
panic reset leaves the tracked `main.tf` exactly as CI verified it.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.
> `git checkout -- main.tf` is the belt-and-braces revert for the temporary edits
> in Steps 1, 2, 4, and 5.

Re-enter `labs/day-1/09-best-practices/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- **`for_each` over the objects, not just keys.** The map values here carry only
- **Chain two `moved` blocks.** Rename the resource *and* re-key it in one refactor
- **Contrast with `removed`.** On the slides you saw the `removed` block: it drops a

Example verification from the workdir:

```bash
cd labs/day-1/09-best-practices
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
