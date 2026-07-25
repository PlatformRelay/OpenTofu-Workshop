# Lab 22 — Code generation

| | |
| --- | --- |
| **Section** | S22 — Code generation |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 30 min |

## Objective

Replace duplicated backend/provider HCL with **root globals** +
`generate_hcl`, run `terramate generate` for every stack, and feel the
break→fix when a generated file goes **stale** — regenerate restores it.

No Docker required. Leaves keep only stack-specific `main.tf`; shared OpenTofu
boilerplate is generated.

## Prerequisites

- Lab 21 completed conceptually (tagged stacks, `terramate list`).
- OpenTofu ≥1.8 (`tofu version`).
- Terramate on `PATH` (`task setup` / `bash setup/bootstrap.sh`).
- A terminal at the repository root.

## Files used

- [`labs/day-3/22-codegen/`](./22-codegen/) — Day-3 monorepo workdir (S21 stacks
  **plus** root globals / generate blueprints and generated `_*.tf`). Extends
  S21; do **not** edit `labs/day-3/21-stacks/`.
- [`globals.tm.hcl`](./22-codegen/globals.tm.hcl) — shared dials.
- [`backend.tm.hcl`](./22-codegen/backend.tm.hcl) — `generate_hcl "_backend.tf"`.
- [`providers.tm.hcl`](./22-codegen/providers.tm.hcl) — `generate_hcl "_providers.tf"`.
- [`stacks/network/_backend.tf`](./22-codegen/stacks/network/_backend.tf) —
  generated backend (slide ↔ lab source of truth).

Root globals (tracked):

<!-- source: labs/day-3/22-codegen/globals.tm.hcl -->
```hcl
globals {
  terraform_version      = ">= 1.8"
  local_provider_version = "~> 2.5"
  backend_path           = "terraform.tfstate"
}
```

Backend blueprint (tracked):

<!-- source: labs/day-3/22-codegen/backend.tm.hcl -->
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

Generated backend (tracked — identical in `stacks/app/` until a leaf overrides
globals):

<!-- source: labs/day-3/22-codegen/stacks/network/_backend.tf -->
```hcl
// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

---

## Step 1 — Terramate on `PATH`

From the repository root:

```bash
command -v terramate >/dev/null \
  || { printf '%s\n' "terramate not found on PATH — run: task setup"; exit 1; }
terramate version
```

<details><summary>Solution / expected output</summary>

Spoilers captured on **0.17.1**:

```console
$ terramate version
0.17.1
```

Any current 0.14+ build is fine. Missing binary → the guard prints
`terramate not found on PATH — run: task setup`.

</details>

---

## Step 2 — Disposable root; strip generated files

Copy the workdir, then **remove** the tracked generated `_*.tf` files so the
leaves look like hand-authored stacks again — blueprints remain, outputs gone.

```bash
demo="$(mktemp -d)"
cp -R labs/day-3/22-codegen/. "$demo/"
cd "$demo"
rm -f stacks/*/_backend.tf stacks/*/_providers.tf
git init -q
git add -A
git commit -qm 'stacks without generated HCL'
terramate list
ls stacks/network/
```

**Task:** Which stacks are discovered? Which `.tf` files remain in
`stacks/network/`?

<details><summary>Solution / expected output</summary>

```console
$ terramate list
stacks/app
stacks/network

$ ls stacks/network/
main.tf
stack.tm.hcl
```

Discovery still works — `stack {}` is untouched. Only the generated shared HCL
is missing. OpenTofu would still infer the `local` provider from `main.tf`, but
the explicit backend / version pins are gone until you generate.

</details>

---

## Step 3 — Generate backend + provider for all stacks

```bash
terramate generate
ls stacks/network/ stacks/app/
diff -u stacks/network/_backend.tf stacks/app/_backend.tf
diff -u stacks/network/_providers.tf stacks/app/_providers.tf
cat stacks/network/_backend.tf
```

<details><summary>Solution / expected output</summary>

```console
$ terramate generate
Code generation report

Successes:

- /stacks/app
	[+] _backend.tf
	[+] _providers.tf

- /stacks/network
	[+] _backend.tf
	[+] _providers.tf

Hint: '+', '~' and '-' mean the file was created, changed and deleted, respectively.

$ ls stacks/network/ stacks/app/
stacks/app/:
_backend.tf
_providers.tf
main.tf
stack.tm.hcl

stacks/network/:
_backend.tf
_providers.tf
main.tf
stack.tm.hcl

$ diff -u stacks/network/_backend.tf stacks/app/_backend.tf
$ diff -u stacks/network/_providers.tf stacks/app/_providers.tf

$ cat stacks/network/_backend.tf
// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

Empty `diff` output means the files are byte-identical — one blueprint, two
stacks. Re-running `terramate generate` with no changes prints
`Nothing to do, generated code is up to date`.

</details>

---

## Step 4 — Prove a leaf still validates as OpenTofu

Still inside `"$demo"`:

```bash
tofu -chdir=stacks/network init -backend=false -input=false
tofu -chdir=stacks/network validate -no-color
```

<details><summary>Solution / expected output</summary>

```console
Success! The configuration is valid.
```

Generated `_providers.tf` and `_backend.tf` sit in the **stack root** beside
`main.tf`. OpenTofu does not load nested directories — that is why the lab emits
`_backend.tf`, not `_gen/backend.tf`.

</details>

---

## Step 5 — Break → fix: stale generated file → `terramate generate`

Corrupt the app backend on purpose, then regenerate:

```bash
printf '\n# STALE hand-edit — do not keep\n' >> stacks/app/_backend.tf
terramate generate --detailed-exit-code; echo "generate exit: $?"
cat stacks/app/_backend.tf
```

**Task:** Did generate rewrite the file? What exit code did
`--detailed-exit-code` return?

<details><summary>Solution / expected observation</summary>

```console
$ terramate generate --detailed-exit-code; echo "generate exit: $?"
Code generation report

Successes:

- /stacks/app
	[~] _backend.tf

Hint: '+', '~' and '-' mean the file was created, changed and deleted, respectively.
generate exit: 2

$ cat stacks/app/_backend.tf
// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

`[~]` means the file **changed** (restored). Detailed exit `2` = changes were
made (`0` = up to date, `1` = error). Fix the **blueprint** or **globals** when
you need a real change — never leave hand-edits in generated files.

</details>

---

## Expected observations

- Stripping `_*.tf` leaves discovery intact; shared HCL is gone until generate.
- `terramate generate` writes `_backend.tf` and `_providers.tf` into **every**
  stack from one root blueprint + globals.
- Sibling stacks match byte-for-byte when they share the same globals.
- Stale / hand-edited generated files are rewritten; detailed exit `2` signals
  drift was corrected.

## Cleanup / panic reset

```bash
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked tree under labs/day-3/22-codegen/ is never mutated by this lab
```

## Stretch

- Inside `"$demo"`, add a leaf override and regenerate:

  ```bash
  cat > stacks/app/globals.tm.hcl <<'EOF'
  globals {
    backend_path = "app.tfstate"
  }
  EOF
  terramate generate
  cat stacks/app/_backend.tf
  cat stacks/network/_backend.tf
  ```

  App should resolve `path = "app.tfstate"`; network keeps `terraform.tfstate`.
  Reset with `rm stacks/app/globals.tm.hcl && terramate generate` before leaving.

- Peek ahead: add `after = ["network"]` under `stack` in
  `stacks/app/stack.tm.hcl` — ordering is S23; reset before leaving.
