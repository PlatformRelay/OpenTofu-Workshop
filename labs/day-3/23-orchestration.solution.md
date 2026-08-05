# Lab 23 — Orchestration & ordering — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-3/23-orchestration/` unless a step says otherwise.

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

### Step 2 — Disposable root; commit the ordered stacks

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

---

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

### Step 3 — Inspect the run-graph and dry-run

Still inside `"$demo"`:

```bash
terramate experimental run-graph
terramate run --dry-run -- echo STACK
```

---

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

### Step 4 — Ordered `tofu init` + `tofu plan`

Run OpenTofu across both stacks in dependency order:

```bash
terramate run -- tofu init -input=false
terramate run -- tofu plan -input=false -no-color
```

**Task:** Which stack plans first? What resource does each plan create?

---

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

### Step 5 — Break → fix: ordering cycle

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

## Expected state / output

- Plain `terramate list` is **not** run order; use `--run-order`.
- `after = ["tag:networking"]` on app makes network run first.
- `terramate experimental run-graph` draws the DAG; cycles paint edges red.
- `terramate run -- tofu …` walks stacks in dependency order.
- A cycle fails `list --run-order` and `run` with a clear path — remove one edge.

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
# tracked tree under labs/day-3/23-orchestration/ is never mutated by this lab
```

Re-enter `labs/day-3/23-orchestration/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- Inside `"$demo"`, destroy in reverse order:

  ```bash
  terramate run --reverse -- tofu destroy -auto-approve -input=false -no-color
  ```

  App should destroy before network. Reset with a fresh `apply` if you want
  markers back.

- Peek ahead: `terramate run --tags=app -- tofu plan` filters to one stack —
  change detection / tag filters are S24; reset before leaving.

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
