# Lab 22 — Code generation — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-3/22-codegen/` unless a step says otherwise.

### Step 1 — Terramate on `PATH`

From the repository root:

```bash
command -v terramate >/dev/null \
  || { printf '%s\n' "terramate not found on PATH — run: task setup"; exit 1; }
terramate version
```

---

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

### Step 2 — Disposable root; strip generated files

Copy the workdir, then **remove** the tracked generated `_*.tf` files so the
leaves look like hand-authored stacks again — blueprints remain, outputs gone.

```bash
demo="$(mktemp -d)"
cp -R labs/day-3/22-codegen/. "$demo/"
cd "$demo"
rm -f stacks/*/_backend.tf stacks/*/_providers.tf
git init -q
git add -A
git -c user.email=learner@example.invalid -c user.name=Learner commit -qm 'stacks without generated HCL'
terramate list
ls stacks/network/
```

**Task:** Which stacks are discovered? Which `.tf` files remain in
`stacks/network/`?

---

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

### Step 3 — Generate backend + provider for all stacks

```bash
terramate generate
ls stacks/network/ stacks/app/
diff -u stacks/network/_backend.tf stacks/app/_backend.tf
diff -u stacks/network/_providers.tf stacks/app/_providers.tf
cat stacks/network/_backend.tf
```

---

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

### Step 4 — Prove a leaf still validates as OpenTofu

Still inside `"$demo"`:

```bash
tofu -chdir=stacks/network init -backend=false -input=false
tofu -chdir=stacks/network validate -no-color
```

---

<details><summary>Solution / expected output</summary>

```console
Success! The configuration is valid.
```

Generated `_providers.tf` and `_backend.tf` sit in the **stack root** beside
`main.tf`. OpenTofu does not load nested directories — that is why the lab emits
`_backend.tf`, not `_gen/backend.tf`.

</details>

---

### Step 5 — Break → fix: stale generated file → `terramate generate`

Corrupt the app backend on purpose, then regenerate:

```bash
printf '\n# STALE hand-edit — do not keep\n' >> stacks/app/_backend.tf
terramate generate --detailed-exit-code; echo "generate exit: $?"
cat stacks/app/_backend.tf
```

**Task:** Did generate rewrite the file? What exit code did
`--detailed-exit-code` return?

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

## Expected state / output

- Stripping `_*.tf` leaves discovery intact; shared HCL is gone until generate.
- `terramate generate` writes `_backend.tf` and `_providers.tf` into **every**
  stack from one root blueprint + globals.
- Sibling stacks match byte-for-byte when they share the same globals.
- Stale / hand-edited generated files are rewritten; detailed exit `2` signals
  drift was corrected.

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

If a step fails mid-lab, return to a clean tree before retrying:

```bash
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked tree under labs/day-3/22-codegen/ is never mutated by this lab
```

Re-enter `labs/day-3/22-codegen/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

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

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
