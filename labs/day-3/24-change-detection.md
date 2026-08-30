# Lab 24 — Change detection & filtering

| | |
| --- | --- |
| **Section** | S24 — Change detection & filtering |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 25 min |

## Objective

Create a **Git baseline** on `main`, change **one** stack on a feature
branch, and prove **`terramate run --changed`** enters only that stack.
Filter with **`--tags`**, then hit the **dirty-worktree** edge —
`run --changed` fails closed until the tree is clean again.

No Docker required. Extends the S23 orchestration monorepo; do **not** edit
`labs/day-3/23-orchestration/`.

## Prerequisites

- Lab 23 completed conceptually (`after` / run-order).
- OpenTofu ≥1.9 (`tofu version`).
- Terramate on `PATH` (`task setup` / `bash setup/bootstrap.sh`).
- A terminal at the repository root.

## Files used

- [`labs/day-3/24-change-detection/`](./24-change-detection/) — Day-3 monorepo
  workdir (S23 orchestration stacks **plus** the same `default_branch`).
  Copy into a disposable directory; never mutate the tracked tree.
- [`terramate.tm.hcl`](./24-change-detection/terramate.tm.hcl) — Git change
  baseline on `main` (slide ↔ lab source of truth).
- [`stacks/app/stack.tm.hcl`](./24-change-detection/stacks/app/stack.tm.hcl) —
  tags used by `--tags=app`.

Root config (tracked):

<!-- source: labs/day-3/24-change-detection/terramate.tm.hcl -->
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

App stack tags (tracked):

<!-- source: labs/day-3/24-change-detection/stacks/app/stack.tm.hcl -->
```hcl
stack {
  name        = "app"
  description = "Application workload"
  tags        = ["app", "compute"]
  id          = "22222222-2222-2222-2222-222222222222"
  after       = ["tag:networking"]
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

## Step 2 — Disposable root; baseline on `main`

Copy the workdir and create a disposable git root. Pin learner identity on
**every** commit (same one-shot pattern as S20/S22/S23 — bare `git commit`
is wrong).

```bash
demo="$(mktemp -d)"
cp -R labs/day-3/24-change-detection/. "$demo/"
cd "$demo"
git init -q
git checkout -q -b main
git add -A
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'baseline stacks from S23'
terramate list --run-order
```

**Task:** Why does `terramate list --changed` fail on this single-commit
`main`?

<details><summary>Solution / expected output</summary>

```console
$ terramate list --run-order
stacks/network
stacks/app

$ terramate list --changed; echo "exit: $?"
Error: flag --changed requires a repository with at least two commits
exit: 1
```

Change detection needs a **second** commit (or a feature branch tip) to
diff against `default_branch`. The baseline alone is not enough — that is
by design, not a broken install.

</details>

---

## Step 3 — Feature branch; change **app** only

Branch off `main`, edit only the app leaf, commit with the identity pin:

```bash
git checkout -q -b feature/change-app
cat > stacks/app/main.tf <<'EOF'
resource "local_file" "marker" {
  filename = "${path.module}/app.marker"
  content  = "app-v2\n"
}
EOF
git add stacks/app/main.tf
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'change app marker content'
terramate list --changed --why
terramate run --changed -- echo ONLY_APP
terramate run --dry-run -- echo ALL
```

**Task:** Which stacks does `--changed` enter? Which does a full dry-run enter?

<details><summary>Solution / expected output</summary>

```console
$ terramate list --changed --why
stacks/app - stack has unmerged changes

$ terramate run --changed -- echo ONLY_APP
terramate: Entering stack in /stacks/app
terramate: Executing command "echo ONLY_APP"
ONLY_APP

$ terramate run --dry-run -- echo ALL
terramate: (dry-run) Entering stack in /stacks/network
terramate: (dry-run) Executing command "echo ALL"
terramate: (dry-run) Entering stack in /stacks/app
terramate: (dry-run) Executing command "echo ALL"
```

**Only `stacks/app`** is selected by `--changed`. A full run still walks
**network then app** (S23 order). That is the monorepo PR proof: plan what
the branch moved.

Optional OpenTofu (still mock, no Docker) — init once, then plan only the
changed stack:

```bash
terramate run -- tofu init -input=false
terramate run --changed -- tofu plan -input=false -no-color
```

Only `/stacks/app` should print a plan.

</details>

---

## Step 4 — Filter by `--tags`

Still inside `"$demo"` on `feature/change-app`:

```bash
terramate list --tags=app
terramate run --tags=networking -- echo NET
terramate run --changed --tags=app -- echo BOTH
terramate run --changed --tags=networking -- echo NONE; echo "exit: $?"
```

**Task:** What is the intersection of `--changed` and `--tags=networking`?

<details><summary>Solution / expected output</summary>

```console
$ terramate list --tags=app
stacks/app

$ terramate run --tags=networking -- echo NET
terramate: Entering stack in /stacks/network
terramate: Executing command "echo NET"
NET

$ terramate run --changed --tags=app -- echo BOTH
terramate: Entering stack in /stacks/app
terramate: Executing command "echo BOTH"
BOTH

$ terramate run --changed --tags=networking -- echo NONE; echo "exit: $?"
exit: 0
```

`--changed` ∩ `--tags=networking` is **empty** — app changed, network did
not, and network is the networking tag. Empty selection exits **0** with no
`Entering` lines. Flags combine as intersection, not union.

</details>

---

## Step 5 — Break → fix: dirty worktree

Leave an **uncommitted** edit, then try `--changed` again:

```bash
cat > stacks/app/main.tf <<'EOF'
resource "local_file" "marker" {
  filename = "${path.module}/app.marker"
  content  = "app-dirty\n"
}
EOF
terramate list --changed --why
terramate run --changed -- echo DIRTY; echo "run exit: $?"
```

**Task:** What error does `run --changed` print? Does `list --changed` still
work?

<details><summary>Solution / expected observation</summary>

```console
$ terramate list --changed --why
stacks/app - stack has unmerged changes

$ terramate run --changed -- echo DIRTY; echo "run exit: $?"
Error: repository has uncommitted files
run exit: 1
```

`list --changed --why` still explains selection. **`run --changed` fails
closed** — Terramate will not execute against a dirty tree. Fix by discarding
the dirt (or committing it with the identity pin):

```bash
git checkout -- stacks/app/main.tf
terramate run --changed -- echo CLEAN
```

```console
$ terramate run --changed -- echo CLEAN
terramate: Entering stack in /stacks/app
terramate: Executing command "echo CLEAN"
CLEAN
```

Do **not** invent a “ignore dirty” flag for this lab — commit or discard.

</details>

---

## Expected observations

- A single-commit repo cannot use `--changed` — baseline first, then a
  feature commit.
- `--changed` on a feature branch vs `default_branch = "main"` selects only
  stacks the branch moved.
- `--tags` selects long-lived slices; combined with `--changed` = intersection.
- Dirty worktree: `run --changed` → `Error: repository has uncommitted files`.
- Full `terramate run` still walks every stack in run-order — filter is opt-in.

## Cleanup / panic reset

```bash
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked tree under labs/day-3/24-change-detection/ is never mutated by this lab
```

## Stretch

- Inside `"$demo"`, pass an explicit base:

  ```bash
  terramate list --changed --git-change-base=main --why
  ```

  Same selection as the default when `default_branch = "main"`.

- Peek ahead: a CI job that runs
  `terramate run --changed -- tofu plan -input=false -no-color` on every PR
  is the S25 shape — reset before leaving.
