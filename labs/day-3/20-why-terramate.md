# Lab 20 — Why Terramate

| | |
| --- | --- |
| **Section** | S20 — Why Terramate |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 25 min |

## Objective

Confirm the Terramate CLI is on your `PATH`, initialise the Day-3 monorepo
skeleton as its own disposable git root, and **feel the DRY pain** of
copy-pasted backends and providers across stacks — the problem the rest of
Day 3 removes.

No Docker, no cloud, no `tofu apply` required. S21–S25 extend this same
skeleton (stacks, codegen, orchestration, change detection, CI).

## Prerequisites

- OpenTofu ≥1.8 (`tofu version`).
- Terramate on `PATH` (`task setup` / `bash setup/bootstrap.sh`).
- A terminal at the repository root. No credentials, Docker, or cloud account.

## Files used

- [`labs/day-3/20-why-terramate/terramate.tm.hcl`](./20-why-terramate/terramate.tm.hcl)
  — root Terramate config for the monorepo skeleton.
- [`labs/day-3/20-why-terramate/stacks/network/`](./20-why-terramate/stacks/network/)
  and [`stacks/app/`](./20-why-terramate/stacks/app/) — two leaf configs that
  **duplicate** `backend.tf` and `providers.tf` on purpose (no `stack.tm.hcl`
  yet — that is S21).

Root config (tracked):

<!-- source: labs/day-3/20-why-terramate/terramate.tm.hcl -->
```hcl
terramate {
  required_version = ">= 0.14.0"

  config {
    git {
      default_branch = "main"
    }
  }
}
```

One of the duplicated backends (the other stack is byte-identical):

<!-- source: labs/day-3/20-why-terramate/stacks/network/backend.tf -->
```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

Matching provider boilerplate (also duplicated across stacks):

<!-- source: labs/day-3/20-why-terramate/stacks/network/providers.tf -->
```hcl
terraform {
  required_version = ">= 1.8"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "local" {}
```

Stack-specific leaf (the only intentional difference):

<!-- source: labs/day-3/20-why-terramate/stacks/network/main.tf -->
```hcl
resource "local_file" "marker" {
  filename = "${path.module}/network.marker"
  content  = "network\n"
}
```

---

## Step 1 — Terramate on `PATH` (or a clear pointer)

From the repository root:

```bash
command -v terramate >/dev/null \
  || { printf '%s\n' "terramate not found on PATH — run: task setup"; exit 1; }
terramate version
```

**Task:** What version do you see? If the command is missing, what does the
script print?

<details><summary>Solution / expected output</summary>

When Terramate is installed (spoilers captured on **0.17.1**):

```console
$ terramate version
0.17.1
```

Your patch may differ; any current 0.14+ build is fine for this lab.

When it is **absent**, the guard fails loudly with a setup pointer — not a
cryptic shell error later:

```console
terramate not found on PATH — run: task setup
```

`task setup` (or `bash setup/bootstrap.sh`) detects Terramate and prints the
install hint for your OS. Re-run this step after it succeeds.

</details>

---

## Step 2 — See the DRY pain in the tracked tree

Stay at the repository root and inspect the skeleton:

```bash
find labs/day-3/20-why-terramate -type f ! -name '.gitignore' | sort
diff -u \
  labs/day-3/20-why-terramate/stacks/network/backend.tf \
  labs/day-3/20-why-terramate/stacks/app/backend.tf
diff -u \
  labs/day-3/20-why-terramate/stacks/network/providers.tf \
  labs/day-3/20-why-terramate/stacks/app/providers.tf
```

**Task:** How many files differ between `network` and `app` for backend and
providers? Which file actually differs?

<details><summary>Solution / expected observation</summary>

```console
labs/day-3/20-why-terramate/stacks/app/backend.tf
labs/day-3/20-why-terramate/stacks/app/main.tf
labs/day-3/20-why-terramate/stacks/app/providers.tf
labs/day-3/20-why-terramate/stacks/network/backend.tf
labs/day-3/20-why-terramate/stacks/network/main.tf
labs/day-3/20-why-terramate/stacks/network/providers.tf
labs/day-3/20-why-terramate/terramate.tm.hcl
```

Both `diff` commands exit `0` with **no output** — the backends and providers
are byte-identical copies. Only `main.tf` differs (the stack-specific marker).
That duplication is the scaling tax Terramate codegen (S22) removes.

</details>

---

## Step 3 — Initialise a disposable monorepo root

Terramate treats the **git root** as the project root. The tracked skeleton
lives under this workshop's git tree, so you copy it to a disposable directory,
`git init`, and commit once — that is the "initialise a repo" beat.

```bash
demo="$(mktemp -d)"
cp -R labs/day-3/20-why-terramate/. "$demo/"
cd "$demo"
git init -q
git add -A
git -c user.email=learner@example.invalid -c user.name=Learner commit -qm 'why-terramate skeleton'
pwd
terramate version
terramate list; echo "list exit: $?"
```

**Task:** What does `terramate list` print? Why is that expected?

<details><summary>Solution / expected output</summary>

```console
$ terramate version
0.17.1
$ terramate list; echo "list exit: $?"
list exit: 0
```

`terramate list` prints **nothing** and exits `0`. The directories under
`stacks/` are ordinary OpenTofu roots — they are not Terramate stacks until
S21 adds a `stack {}` block (`stack.tm.hcl`). Discovery is empty on purpose;
the root config is already valid.

If you skipped `git init`, Terramate would still try to walk a parent git root
and warn that `required_version` / `config.git` may only be declared at the
project root — always initialise the disposable copy first.

</details>

---

## Step 4 — Optional: prove one leaf still validates as OpenTofu

Still inside `"$demo"`:

```bash
tofu -chdir=stacks/network init -backend=false -input=false
tofu -chdir=stacks/network validate -no-color
```

**Task:** Does validate succeed without Terramate inventing a backend?

<details><summary>Solution / expected output</summary>

```console
Success! The configuration is valid.
```

Each leaf keeps its **own** local backend path and provider block. Terramate
did not create, move, or lock state — it only sat above the tree. State
management remains OpenTofu's job (and your CI/backend's), which is the
headline of S20.

</details>

---

## Expected observations

- Missing Terramate → explicit `task setup` pointer.
- `network` and `app` share identical `backend.tf` / `providers.tf` (DRY pain).
- After copy + `git init`, `terramate list` is empty until S21.
- OpenTofu still validates a leaf on its own; Terramate does not own state.

## Cleanup / panic reset

```bash
# return to the workshop checkout, then drop the disposable root
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked skeleton under labs/day-3/20-why-terramate/ is never mutated by this lab
```

If you experimented with `tofu apply` inside `"$demo"`, deleting that directory
removes any local state and markers. The repository workdir stays clean
(`.gitignore` already excludes `.terraform/`, `*.tfstate`, and `*.marker`).

## Stretch

- From `"$demo"`, run `terramate create stacks/network --name network` and
  re-run `terramate list`. You are peeking at S21 — reset with
  `rm -f stacks/network/stack.tm.hcl` (or delete `"$demo"`) before the next lab.
