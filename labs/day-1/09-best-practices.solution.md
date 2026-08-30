# Lab 09 — count vs for_each, dynamic blocks, and refactor without replacement (S09) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally. All
spoilers were captured on OpenTofu **1.12.5**.

## Guided solutions

Work from the tracked workdir `labs/day-1/09-best-practices/` unless a step says
otherwise. The workdir holds four canonical files: `main.tf` (the `for_each` +
`moved` end state), `bundle.tf` (the `dynamic` end state), `rename.tf` (the
post-rename end state with its `moved` paper trail), and `retire.tf` (the
post-retirement end state — a lone `removed` block).

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/09-best-practices
ls -a
```

<details><summary>Solution / expected output</summary>

```console
$ ls -a
.  ..  .gitignore  bundle.tf  main.tf  rename.tf  retire.tf
```

`main.tf` is the `for_each` end state; `bundle.tf` is the `dynamic` end state
re-derived by hand in Steps 7–8; `rename.tf` and `retire.tf` are Part B's
refactoring end states. Every `.tf` in a directory is part of the module, so
`bundle.tf`'s data source and `rename.tf`'s release-notes resource show up in
plans from the start — harmless until Steps 6 and 10, then the point
(`retire.tf`'s `removed` block matches nothing in fresh state and is a no-op
until Step 12 gives it history).

</details>

---

### Step 1 — Start from `count`: apply three services

**Temporarily** replace `main.tf` with the `count` form from the participant lab
(map of services, `sort(keys(var.services))` flattened into an ordered list,
`count = length(local.service_names)`), then:

```bash
tofu init
tofu apply -auto-approve
tofu state list
```

<details><summary>Solution / expected output</summary>

```console
$ tofu init
...
- Installed hashicorp/local v2.9.0 (signed, key ID 0C0AF313E5FD9F80)
- Installed hashicorp/archive v2.8.0 (signed, key ID 0C0AF313E5FD9F80)
...
OpenTofu has been successfully initialized!

$ tofu apply -auto-approve
data.archive_file.bundle: Reading...
data.archive_file.bundle: Read complete after 0s [id=624f9bc013ee78d910d2745bf26135683eeb9ea8]
...
Plan: 4 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bundle_sha256 = "98817fde81e5659f696dcd4e2fc4a0ee7a9add23359b83f09e5cdec82e2763a6"
...
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

$ tofu state list
data.archive_file.bundle
local_file.manifest[0]
local_file.manifest[1]
local_file.manifest[2]
local_file.release_notes
```

Three manifest instances, addressed by their **sorted-key index**:
`[0]`=checkout, `[1]`=payments, `[2]`=search — a *position*, not an identity.
The extra entries ride along: `data.archive_file.bundle` is `bundle.tf`'s data
source, `local_file.release_notes` is `rename.tf`'s artifact (Part B's
workbench).

</details>

---

### Step 2 — The `count` trap: remove the middle element

Delete the `payments` line from the temporary form's `default` map, then
`tofu plan` — **do not apply**.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest[1] must be replaced
-/+ resource "local_file" "manifest" {
      ~ content              = <<-EOT # forces replacement
          - SERVICE_NAME=payments
          - REPLICAS=4
          + SERVICE_NAME=search
          + REPLICAS=3
        EOT
      ~ filename             = "./out/payments.env" -> "./out/search.env" # forces replacement
...
  # local_file.manifest[2] will be destroyed
  # (because index [2] is out of range for count)
...
Plan: 1 to add, 0 to change, 2 to destroy.
```

One service removed, **two destroyed**: the sorted keys shift down, so `[1]` is
recomputed as *search* and replaced (immutable resource), while `[2]` falls out
of range. The kept service gets churned. Revert `payments` into the map and
`tofu apply -auto-approve` reports `No changes`.

</details>

---

### Step 3 — Refactor to `for_each` **without replacement** using `moved`

```bash
git checkout -- main.tf
tofu plan
tofu apply -auto-approve
tofu state list
```

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest[0] has moved to local_file.manifest["checkout"]
  # local_file.manifest[1] has moved to local_file.manifest["payments"]
  # local_file.manifest[2] has moved to local_file.manifest["search"]
...
Plan: 0 to add, 0 to change, 0 to destroy.

$ tofu apply -auto-approve
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

$ tofu state list
data.archive_file.bundle
local_file.manifest["checkout"]
local_file.manifest["payments"]
local_file.manifest["search"]
local_file.release_notes
```

Every instance is reported as `has moved to` — a pure state rename, nothing on
disk recreated. `moved` decouples "I re-keyed this in code" from "rebuild it in
the world."

</details>

---

### Step 4 — Prove the fix, then mis-key the map

Delete the `payments` entry from the keyed map and plan — **do not apply**.
Then, with `payments` still deleted, append the temporary mis-keyed output from
the participant lab and plan again.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.manifest["payments"] will be destroyed
  # (because key ["payments"] is not in for_each map)
...
Plan: 0 to add, 0 to change, 1 to destroy.
```

Surgical: only the removed key is destroyed; `checkout` and `search` aren't in
the plan at all. With the leftover lookup appended:

```console
$ tofu plan
...
╷
│ Error: Invalid index
│
│   on main.tf line 54, in output "payments_replicas":
│   54:   value = var.services["payments"].replicas
│     ├────────────────
│     │ var.services is map of object with 2 elements
│
│ The given key does not identify an element in this collection value.
╵
```

Keys are exact, case-sensitive strings; a mis-keyed lookup fails loudly at
**plan** time with file, line, and collection size. Fix both edits at once:

```console
$ git checkout -- main.tf
$ tofu apply -auto-approve
No changes. Your infrastructure matches the configuration.
```

</details>

---

### Step 5 — Break → fix: an edit that silently forces a re-create

Change the `filename` extension to `.conf` in `main.tf`, plan, read the
replacement signals, then revert with `git checkout -- main.tf`.

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

A one-word cosmetic change wants to rebuild the whole fleet, and
`# forces replacement` names the exact attribute. After
`git checkout -- main.tf`, `tofu plan` is a clean `No changes`.

</details>

---

### Step 6 — Meet the `dynamic` block

```bash
tofu output bundle_sha256
unzip -l out/bundle.zip
unzip -p out/bundle.zip checkout.env
```

<details><summary>Solution / expected output</summary>

```console
$ tofu output bundle_sha256
"98817fde81e5659f696dcd4e2fc4a0ee7a9add23359b83f09e5cdec82e2763a6"

$ unzip -l out/bundle.zip
Archive:  out/bundle.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
       11  00-00-1980 00:00   checkout.env
       11  00-00-1980 00:00   payments.env
       11  00-00-1980 00:00   search.env
---------                     -------
       33                     3 files

$ unzip -p out/bundle.zip checkout.env
REPLICAS=2
```

One zip entry per `var.services` key, each stamped out by one iteration of
`dynamic "source"`. The iterator is named after the **label** (`source.key` /
`source.value`), not `each`.

</details>

---

### Step 7 — The copy-paste bundle, and what it silently forgets

Replace `bundle.tf` with the three literal `source {}` blocks from the
participant lab and plan; then add the temporary `billing` service to the map in
`main.tf` and plan again.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
data.archive_file.bundle: Reading...
data.archive_file.bundle: Read complete after 0s [id=624f9bc013ee78d910d2745bf26135683eeb9ea8]

No changes. Your infrastructure matches the configuration.
```

The literal blocks expand to exactly what the `dynamic` block generated (same
entries, sorted-key order), so the zip is byte-identical — `dynamic` is pure
authoring-time sugar. With `billing` added:

```console
$ tofu plan
...
  # local_file.manifest["billing"] will be created
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

`for_each` picked up the new service; the hand-copied bundle **did not** — and
there is *no* output change, diff, or warning saying so. The deploy bundle would
ship without `billing.env`. Copy-paste config fails silently because the same
data lives in two places and only one is wired to change.

</details>

---

### Step 8 — Write the `dynamic` block yourself

Replace the literal blocks with a `dynamic "source"` block using `each.*` first
(the deliberate break), plan, read both errors, then fix `each.` → `source.` and
plan again. Finally revert `billing`, diff, and adopt the canonical file.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
╷
│ Error: Reference to "each" in context without for_each
│
│   on bundle.tf line 9, in data "archive_file" "bundle":
│    9:       filename = "${each.key}.env"
│
│ The "each" object can be used only in "module" or "resource" blocks, and
│ only when the "for_each" argument is set.
╵
╷
│ Error: each.value cannot be used in this context
│
│   on bundle.tf line 10, in data "archive_file" "bundle":
│   10:       content  = "REPLICAS=${each.value.replicas}\n"
│
│ A reference to "each.value" has been used in a context in which it is
│ unavailable, such as when the configuration no longer contains the value in
│ its "for_each" expression. Remove this reference to each.value in your
│ configuration to work around this error.
╵
```

(The errors repeat once per element.) `each` exists only for resource/module
`for_each`; a `dynamic` block's iterator is named after its **label** (or an
explicit `iterator =`). After the fix:

```console
$ tofu plan
...
  # local_file.manifest["billing"] will be created
...
Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  ~ bundle_sha256 = "98817fde81e5659f696dcd4e2fc4a0ee7a9add23359b83f09e5cdec82e2763a6" -> "4b92d23124397dce475949b4e71bab753cd17a52a1219635869ce00f7768c78e"

$ unzip -l out/bundle.zip
Archive:  out/bundle.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
       11  00-00-1980 00:00   billing.env
       11  00-00-1980 00:00   checkout.env
       11  00-00-1980 00:00   payments.env
       11  00-00-1980 00:00   search.env
---------                     -------
       44                     4 files
```

Now one map entry updates both fan-outs in a single plan. Converge:

```console
$ git checkout -- main.tf
$ git diff -- bundle.tf
...(comment lines only — your TEMPORARY header vs the tracked one)...
$ git checkout -- bundle.tf
$ tofu plan
...
No changes. Your infrastructure matches the configuration.
```

</details>

---

### Step 9 — Fan-out width unknown at plan time

Create the temporary scratch `receipts.tf` from the participant lab (gitignored)
and plan; try the suggested `-exclude` workaround; then apply the structural fix
and delete the scratch file.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
Plan: 1 to add, 0 to change, 0 to destroy.
╷
│ Error: Invalid count argument
│
│   on receipts.tf line 11, in resource "local_file" "receipt":
│   11:   count    = length(local_file.audit.content_sha256)
│
│ The "count" value depends on resource attributes that cannot be determined
│ until apply, so OpenTofu cannot predict how many instances will be created.
│
│ To work around this, use the planning option -exclude=local_file.receipt to
│ first apply without this object, and then apply normally to converge.
╵
```

A plan is a complete promise: a width that is `(known after apply)` cannot be
planned, and `for_each` applies the same rule to its keys. The two-pass
workaround (needs ≥ 1.9):

```console
$ tofu plan -exclude=local_file.receipt
...
  # local_file.audit will be created
...
Plan: 1 to add, 0 to change, 0 to destroy.
╷
│ Warning: Resource targeting is in effect
...
```

The structural fix — `count = length(var.services)` — plans in one pass:

```console
$ tofu plan
...
  # local_file.audit will be created
  # local_file.receipt[0] will be created
  # local_file.receipt[1] will be created
  # local_file.receipt[2] will be created
Plan: 4 to add, 0 to change, 0 to destroy.
```

Do not apply; `rm receipts.tf` and `tofu plan` returns `No changes`.

</details>

---

### Step 10 — Time-travel to the legacy layout (and replay `state rm`)

Forget the release notes imperatively, observe the half-done retirement, then
install the temporary legacy forms of `rename.tf` (resource at address
`local_file.notes`, no `moved` block) and `retire.tf` (managed
`local_file.build_info` plus the `build_info_path` output) from the
participant lab, and apply.

<details><summary>Solution / expected output</summary>

```console
$ tofu state rm local_file.release_notes
Removed local_file.release_notes
Successfully removed 1 resource instance(s).

$ ls out/RELEASE.md
out/RELEASE.md

$ tofu plan
...
  # local_file.release_notes will be created
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

`state rm` forgets without destroying (the file survives), but the config
still declares the resource, so the next plan re-creates it — the imperative
tool does half the retirement and leaves the config edit as a separate,
unreviewed step.

After installing both temporary legacy files:

```console
$ tofu apply -auto-approve
...
  # local_file.build_info will be created
  # local_file.notes will be created
...
Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + build_info_path = "./out/build-info.env"
...
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

$ tofu state list
data.archive_file.bundle
local_file.build_info
local_file.manifest["checkout"]
local_file.manifest["payments"]
local_file.manifest["search"]
local_file.notes
```

The "before" is live: release notes at the legacy `local_file.notes` address
(the create rewrote `out/RELEASE.md` with identical bytes), build metadata
managed at `local_file.build_info`.

</details>

---

### Step 11 — Rename: destroy/create without `moved`, no-op with it

Rename the block label `notes` → `release_notes` in the temporary `rename.tf`
and plan (**no apply**); then append the `moved` block by hand, plan, and
converge via `git checkout -- rename.tf` before applying.

<details><summary>Solution / expected output</summary>

Without `moved`:

```console
$ tofu plan
...
  # local_file.notes will be destroyed
  # (because local_file.notes is not in configuration)
...
  # local_file.release_notes will be created
...
Plan: 1 to add, 0 to change, 1 to destroy.
```

With the hand-written `moved { from = local_file.notes  to =
local_file.release_notes }`:

```console
$ tofu plan
...
  # local_file.notes has moved to local_file.release_notes
    resource "local_file" "release_notes" {
        id                   = "8b2a534a4b1a8f4c5e7dfbc2fe70ce23bc58dfcf"
        # (10 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

Converge and commit the move:

```console
$ git diff -- rename.tf
...(comment lines only)...
$ git checkout -- rename.tf
$ tofu apply -auto-approve
  # local_file.notes has moved to local_file.release_notes
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

`tofu state list` now shows `local_file.release_notes`; the unchanged `id`
across the move is the proof it is the same object under a new address.

</details>

---

### Step 12 — Retire with `removed`: forget, don't destroy

In the temporary `retire.tf`: delete the resource block (plan errors on the
dangling output), delete the output too (plan proposes a destroy — no apply),
then write the `removed` block — minimal form first, then with
`lifecycle { destroy = false }` — and converge via `git checkout -- retire.tf`
before applying.

<details><summary>Solution / expected output</summary>

Resource deleted, output still present:

```console
$ tofu plan
...
│ Error: Reference to undeclared resource
│
│   on retire.tf line 5, in output "build_info_path":
│    5:   value = local_file.build_info.filename
│
│ There is no managed resource "local_file" "build_info" definition in the root
│ module.
```

Output deleted as well — plain code deletion means destroy:

```console
$ tofu plan
...
  # local_file.build_info will be destroyed
  # (because local_file.build_info is not in configuration)
...
Plan: 0 to add, 0 to change, 1 to destroy.
```

Minimal `removed { from = local_file.build_info }`:

```console
$ tofu plan
...
│ Warning: Missing lifecycle from the removed block
...
  # local_file.build_info will be removed from the OpenTofu state but will not be destroyed
  . resource "local_file" "build_info" {
...
Plan: 0 to add, 0 to change, 0 to destroy, 1 to forget.
```

Adding `lifecycle { destroy = false }` keeps the identical forget plan and
silences the warning (while `destroy = true` would flip the same block to
`1 to destroy`). Converge and apply:

```console
$ git checkout -- retire.tf
$ tofu apply -auto-approve
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed, 1 forgotten.

$ tofu state list
data.archive_file.bundle
local_file.manifest["checkout"]
local_file.manifest["payments"]
local_file.manifest["search"]
local_file.release_notes

$ cat out/build-info.env
BUILD_CHANNEL=stable

$ tofu plan
...
No changes. Your infrastructure matches the configuration.
```

State no longer holds `build_info`, the artifact is intact on disk, and the
follow-up plan is clean — the applied `removed` block stays as inert,
reviewable history.

</details>

---

## Expected state / output

- **Step 2 vs Step 4:** the identical middle-element removal planned
  `1 to add, 2 to destroy` under `count` but `0 to add, 1 to destroy` under
  `for_each` — the surviving instances appear in the `count` plan and are absent
  from the `for_each` plan.
- **Step 3:** the `count` → `for_each` migration planned and applied
  `0 to add, 0 to change, 0 to destroy` with three `has moved to` lines;
  `tofu state list` ends keyed (`manifest["checkout"]` …).
- **Step 4 break:** `Error: Invalid index … The given key does not identify an
  element in this collection value`, naming file and line.
- **Step 5:** `Plan: 3 to add, 0 to change, 3 to destroy` with
  `# forces replacement` on each `filename` line; clean `No changes` after
  revert.
- **Steps 6–8:** `bundle_sha256` output `98817fde…` with 3 zip entries; the
  static regression planned `No changes`; the silent-forget break planned
  `1 to add` with **no** bundle output change; the fixed dynamic form planned
  `1 to add` **plus** `~ bundle_sha256 … -> 4b92d231…` and a 4-entry zip.
- **Step 9:** `Error: Invalid count argument` suggesting
  `-exclude=local_file.receipt`; the structural fix planned
  `4 to add, 0 to change, 0 to destroy`.
- **Step 10:** `state rm` printed `Removed local_file.release_notes` with the
  file surviving on disk; the follow-up plan wanted to re-create it; the
  legacy layout applied `2 to add`.
- **Step 11:** the plain rename planned `1 to add, 0 to change, 1 to destroy`
  without `moved` and `0 to add, 0 to change, 0 to destroy` with it — the
  moved instance keeping its `id`.
- **Step 12:** the dangling reference errored (`Reference to undeclared
  resource`); plain deletion planned `1 to destroy`; the `removed` block
  planned `0 to destroy, 1 to forget` and applied as `1 forgotten`, with
  `out/build-info.env` intact and `tofu state list` no longer showing
  `build_info`.
- **Cleanup:** `Destroy complete! Resources: 4 destroyed.` and an empty
  `git status --short`.

## Explanation

OpenTofu reconciles declared configuration against stored state on every plan
and apply, and an instance's **address is its identity** in that reconciliation.
`count` derives addresses from positions, so removing a middle element re-keys
every later instance and — because `local_file` is immutable — forces
destroy+recreate; `for_each` derives addresses from map keys, so the same
removal touches one instance. `moved` blocks edit the address-to-object binding
directly in state, which is why the migration plans as zero actions. A `dynamic`
block is expansion sugar evaluated before the provider sees the config — the
provider receives identical nested blocks whether they were literal or
generated, which is why the regression planned `No changes` and why the iterator
is scoped to the block (named after the label) rather than being the resource's
`each`. And because a plan must fully enumerate instances before apply, a
fan-out width that depends on an unapplied resource's computed attribute cannot
be planned — deriving width from configuration removes the dependency, so the
single-pass plan succeeds. Part B extends the same identity model to the two
refactoring verbs: a rename creates a *new* address, so without help the
reconciliation sees one resource gone and another born — destroy plus create —
while a `moved` block edits the address-to-object binding in state, leaving the
object (and its `id`) untouched. Deleting configuration means "this object
should not exist," which is why plain deletion plans a destroy; a `removed`
block replaces that meaning with "stop tracking this object," a distinct
**forget** action that leaves the real artifact alone, and its
`lifecycle.destroy` boolean is the explicit, reviewable record of which of the
two meanings you chose — the property `tofu state rm`, an immediate unplanned
state edit, cannot offer.

## Troubleshooting and recovery

If a step fails mid-lab, prefer the documented panic reset before editing
tracked files by hand. All commands run from the **repo root**, so this block
recovers you from any half-finished step, wherever you are:

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=labs/day-1/09-best-practices destroy -auto-approve   # tear down the local_file instances
git checkout -- labs/day-1/09-best-practices                     # undo any temporary step edits
rm -f labs/day-1/09-best-practices/receipts.tf                   # drop the Step 9 scratch file (untracked)
rm -rf labs/day-1/09-best-practices/.terraform \
       labs/day-1/09-best-practices/.terraform.lock.hcl \
       labs/day-1/09-best-practices/out
find labs/day-1/09-best-practices -maxdepth 1 -name 'terraform.tfstate*' -delete
git status --short labs/day-1/09-best-practices                  # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or
leak. The generated state / `.terraform` / rendered `out/` files (including
`bundle.zip`) and the scratch `receipts.tf` are gitignored; the panic reset
leaves the tracked `main.tf`, `bundle.tf`, `rename.tf`, and `retire.tf`
exactly as CI verified them. The `.terraform.lock.hcl` removed here is the
*untracked* one this lab's init generates in its own workdir — never a tracked
lockfile.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*`
> glob aborts under zsh's `nomatch` when no such file exists, and `tofu` can
> leave timestamped `.backup` files behind. `find` matches zero-or-more without
> erroring.

Re-enter `labs/day-1/09-best-practices/` and replay from the failing step once
the environment is clean. For provider or module download errors, run
`tofu init -upgrade` in the workdir and retry `tofu plan`.

Part B specifics: `Error: Removed resource block still exists` means the
`resource "local_file" "build_info"` block is still declared next to the
`removed` block — delete the resource block (the `removed` block replaces it,
it cannot coexist with it). If you applied the `destroy = true` variant (or
Attempt 1's deletion) by accident, `out/build-info.env` is gone from disk;
nothing of value is lost — restore the temporary Step 10 `retire.tf`, run
`tofu apply -auto-approve` to re-create it, and replay Step 12. If you
`state rm`'d the wrong address in Step 10, `tofu plan` will simply offer to
re-create it — apply and continue.

## Stretch solution

### Commands / manifest

- **`for_each` over the objects:** add `tier = string` to the map's object type,
  give each service a `tier`, then reference `each.value.tier` in the manifest
  content *and* `source.value.tier` in the bundle content.
- **Chain two `moved` blocks:** rename *and* re-key in one refactor
  (`local_file.manifest[0]` → `local_file.service_env["checkout"]`).
- **Name the iterator explicitly:** add `iterator = svc` to the `dynamic` block
  and switch references to `svc.key` / `svc.value.replicas`.
- **Retire a whole module:** reason through `removed { from = module.checkout }`
  against Lab 07's fan-out — one forget per resource inside the instance, with
  the module block and every output reference deleted in the same diff.

Example verification from the workdir:

```bash
cd labs/day-1/09-best-practices
tofu plan
tofu apply -auto-approve
tofu state list
git checkout -- main.tf bundle.tf
```

### Expected state / output

The `tier` stretch plans `3 to change` (content is mutable-adjacent here via
replacement: for `local_file` it actually plans `must be replaced` — read the
`# forces replacement` marker and decide consciously) plus a `bundle_sha256`
output change. The chained `moved` stretch plans `0 to add, 0 to change,
0 to destroy` with `has moved to` lines for the renamed addresses. The
`iterator = svc` stretch plans `No changes` — naming the iterator does not
change the expansion. The module-retirement stretch is reasoning-only against
Lab 07's workdir: the tally would read `N to forget` (one per resource in the
instance), zero to destroy, and any surviving reference to the module's
outputs would fail at plan time the same way Step 12's dangling output
reference did. After `git checkout -- main.tf bundle.tf`, `tofu plan` returns
`No changes`.

### Explanation

The stretches deepen the same identity model: `each.value`/`source.value` carry
whole objects, so widening the object type flows one input change through both
fan-out levels; `moved` blocks compose because each edits the address binding,
not the object; and an explicit `iterator` only renames the expansion-time
symbol, so the provider-visible config — and therefore the plan — is unchanged.
They stay optional because they reuse the converged end state rather than
advancing it.
