# Lab 23 — Orchestration & ordering

| | |
| --- | --- |
| **Section** | S23 — Orchestration & ordering |
| **Environment** | `mock ✓ (no docker)` |
| **Estimated time** | 30 min |

## Objective

Declare an **`after`** edge so `app` waits for `network`, inspect the
run-graph, and run **`tofu`** across stacks in order. Then break→fix an
ordering **cycle** — read the error, remove one edge, confirm order returns.

No Docker required. Extends the S22 codegen monorepo; do **not** edit
`labs/day-3/22-codegen/`.

## Prerequisites

- Lab 22 completed conceptually (globals + `generate_hcl`).
- OpenTofu ≥1.9 (`tofu version`).
- Terramate on `PATH` (`task setup` / `bash setup/bootstrap.sh`).
- A terminal at the repository root.

## Files used

- [`labs/day-3/23-orchestration/`](./23-orchestration/) — Day-3 monorepo
  workdir (S22 codegen **plus** `after` on app). Copy into a disposable
  directory; never mutate the tracked tree.
- [`stacks/app/stack.tm.hcl`](./23-orchestration/stacks/app/stack.tm.hcl) —
  ordering edge (slide ↔ lab source of truth).
- [`stacks/network/stack.tm.hcl`](./23-orchestration/stacks/network/stack.tm.hcl)
  — foundation stack (no `before` required when app declares `after`).

App stack with ordering (tracked):

<!-- source: labs/day-3/23-orchestration/stacks/app/stack.tm.hcl -->
```hcl
stack {
  name        = "app"
  description = "Application workload"
  tags        = ["app", "compute"]
  id          = "22222222-2222-2222-2222-222222222222"
  after       = ["tag:networking"]
}
```

Network stack (tracked — no reverse edge):

<!-- source: labs/day-3/23-orchestration/stacks/network/stack.tm.hcl -->
```hcl
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
  id          = "11111111-1111-1111-1111-111111111111"
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

## Step 2 — Disposable root; commit the ordered stacks

Copy the workdir and create a disposable git root. Terramate's change-detection
defaults expect a repository; pin learner identity on the one-shot commit (same
pattern as S20/S22).

```bash
demo="$(mktemp -d)"
cp -R labs/day-3/23-orchestration/. "$demo/"
cd "$demo"
git init -q
git add -A
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'ordered stacks from S22 + after'
terramate list
terramate list --run-order
```

**Task:** How does plain `list` order differ from `--run-order`?

<details><summary>Solution / expected output</summary>

```console
$ terramate list
stacks/app
stacks/network

$ terramate list --run-order
stacks/network
stacks/app
```

Plain `list` is discovery order (here `app` before `network`). `--run-order`
honours `after = ["tag:networking"]` — **network first, then app**.

</details>

---

## Step 3 — Inspect the run-graph and dry-run

Still inside `"$demo"`:

```bash
terramate experimental run-graph
terramate run --dry-run -- echo STACK
```

<details><summary>Solution / expected output</summary>

```console
$ terramate experimental run-graph
digraph  {
	
	n1[label="app"];
	n2[label="network"];
	n2->n1;
	
}

$ terramate run --dry-run -- echo STACK
terramate: (dry-run) Entering stack in /stacks/network
terramate: (dry-run) Executing command "echo STACK"
terramate: (dry-run) Entering stack in /stacks/app
terramate: (dry-run) Executing command "echo STACK"
```

`n2->n1` means network precedes app. `--dry-run` prints the walk without
running `echo` for real. Use `--reverse` when destroying (dependents first).

</details>

---

## Step 4 — Ordered `tofu init` + `tofu plan`

Run OpenTofu across both stacks in dependency order:

```bash
terramate run -- tofu init -input=false
terramate run -- tofu plan -input=false -no-color
```

**Task:** Which stack plans first? What resource does each plan create?

<details><summary>Solution / expected output</summary>

Each stack prints `terramate: Entering stack in /stacks/…` — **network**, then
**app**. Truncated shape:

```console
$ terramate run -- tofu plan -input=false -no-color
terramate: Entering stack in /stacks/network
terramate: Executing command "tofu plan -input=false -no-color"
...
Plan: 1 to add, 0 to change, 0 to destroy.
...
terramate: Entering stack in /stacks/app
terramate: Executing command "tofu plan -input=false -no-color"
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

Each plan creates `local_file.marker` (`network.marker` / `app.marker`). Init
must use the generated local backend (omit `-backend=false`) so plan can run.
`.terraform/` and `*.tfstate` stay gitignored — `terramate run` stays happy.

Optional apply (still mock, no Docker):

```bash
terramate run -- tofu apply -auto-approve -input=false -no-color
ls stacks/network/network.marker stacks/app/app.marker
```

</details>

---

## Step 5 — Break → fix: ordering cycle

Add a reverse `after` on network so each stack waits for the other. Commit the
break (keeps the tree clean for later `run` commands), then inspect:

```bash
cat > stacks/network/stack.tm.hcl <<'EOF'
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
  id          = "11111111-1111-1111-1111-111111111111"
  after       = ["tag:app"]
}
EOF
git add stacks/network/stack.tm.hcl
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'break: introduce ordering cycle'
terramate list --run-order; echo "list exit: $?"
terramate run --dry-run -- echo STACK; echo "run exit: $?"
terramate experimental run-graph
```

**Task:** What path does the cycle error print? What colour are the cycle edges
in `run-graph`?

<details><summary>Solution / expected observation</summary>

```console
$ terramate list --run-order; echo "list exit: $?"
Error: cycle detected: Invalid stack configuration: /stacks/app -> /stacks/network -> /stacks/app: checking node id "/stacks/app"
list exit: 1

$ terramate run --dry-run -- echo STACK; echo "run exit: $?"
Error: one or more commands failed
> cycle detected: cycle detected: /stacks/app -> /stacks/network -> /stacks/app: checking node id "/stacks/app"
run exit: 1

$ terramate experimental run-graph
digraph  {
	
	n1[label="app"];
	n2[label="network"];
	n1->n2[color="red"];
	n2->n1[color="red"];
	
}
```

Both edges are **red**. The cycle path is
`/stacks/app -> /stacks/network -> /stacks/app`. Fix by removing **one** edge —
restore network without `after`:

```bash
cat > stacks/network/stack.tm.hcl <<'EOF'
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
  id          = "11111111-1111-1111-1111-111111111111"
}
EOF
git add stacks/network/stack.tm.hcl
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'fix: break ordering cycle'
terramate list --run-order
terramate run --dry-run -- echo STACK
```

```console
$ terramate list --run-order
stacks/network
stacks/app

$ terramate run --dry-run -- echo STACK
terramate: (dry-run) Entering stack in /stacks/network
terramate: (dry-run) Executing command "echo STACK"
terramate: (dry-run) Entering stack in /stacks/app
terramate: (dry-run) Executing command "echo STACK"
```

Order is back. Keep `after` on **app** only — one edge is enough.

</details>

---

## Expected observations

- Plain `terramate list` is **not** run order; use `--run-order`.
- `after = ["tag:networking"]` on app makes network run first.
- `terramate experimental run-graph` draws the DAG; cycles paint edges red.
- `terramate run -- tofu …` walks stacks in dependency order.
- A cycle fails `list --run-order` and `run` with a clear path — remove one edge.

## Cleanup / panic reset

```bash
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked tree under labs/day-3/23-orchestration/ is never mutated by this lab
```

## Stretch

- Inside `"$demo"`, destroy in reverse order:

  ```bash
  terramate run --reverse -- tofu destroy -auto-approve -input=false -no-color
  ```

  App should destroy before network. Reset with a fresh `apply` if you want
  markers back.

- Peek ahead: `terramate run --tags=app -- tofu plan` filters to one stack —
  change detection / tag filters are S24; reset before leaving.
