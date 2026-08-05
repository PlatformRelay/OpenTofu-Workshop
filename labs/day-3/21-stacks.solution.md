# Lab 21 — Stacks — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-3/21-stacks/` unless a step says otherwise.

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

### Step 2 — Disposable root; start from the **flat** leaves

Copy the workdir, then **remove** the tracked `stack.tm.hcl` files so the tree
looks like S20 again — flat OpenTofu roots, no discovery yet.

```bash
demo="$(mktemp -d)"
cp -R labs/day-3/21-stacks/. "$demo/"
cd "$demo"
rm -f stacks/network/stack.tm.hcl stacks/app/stack.tm.hcl
git init -q
git add -A
git commit -qm 'flat leaves — pre-stacks'
terramate list; echo "list exit: $?"
```

**Task:** What does `terramate list` print? Why?

---

<details><summary>Solution / expected output</summary>

```console
$ terramate list; echo "list exit: $?"
list exit: 0
```

Empty list, exit `0`. Directories under `stacks/` are ordinary OpenTofu roots
until a `stack {}` block exists. Discovery is declarative — not a folder walk.

</details>

---

### Step 3 — Split into tagged stacks with `terramate create`

Create both stacks with the same metadata as the tracked files (stable `--id`
keeps the lab aligned with the slides):

```bash
terramate create stacks/network \
  --name network \
  --description 'Shared network foundation' \
  --tags networking,shared \
  --id 11111111-1111-1111-1111-111111111111 \
  --no-generate

terramate create stacks/app \
  --name app \
  --description 'Application workload' \
  --tags app,compute \
  --id 22222222-2222-2222-2222-222222222222 \
  --no-generate

terramate list
cat stacks/network/stack.tm.hcl
```

`--no-generate` skips codegen (S22). `--tags` takes a comma-separated list.

---

<details><summary>Solution / expected output</summary>

```console
$ terramate create stacks/network \
>   --name network \
>   --description 'Shared network foundation' \
>   --tags networking,shared \
>   --id 11111111-1111-1111-1111-111111111111 \
>   --no-generate
Created stack /stacks/network

$ terramate create stacks/app \
>   --name app \
>   --description 'Application workload' \
>   --tags app,compute \
>   --id 22222222-2222-2222-2222-222222222222 \
>   --no-generate
Created stack /stacks/app

$ terramate list
stacks/app
stacks/network

$ cat stacks/network/stack.tm.hcl
stack {
  name        = "network"
  description = "Shared network foundation"
  tags        = ["networking", "shared"]
  id          = "11111111-1111-1111-1111-111111111111"
}
```

Shortcut: `terramate create --all-terraform --no-generate` imports every OpenTofu
root, then you edit tags by hand. Prefer the explicit `--tags` form above so the
files match the tracked teaching artifacts.

</details>

---

### Step 4 — Filter with tags

```bash
terramate list --tags networking
terramate list --tags app
terramate list --tags 'networking:shared'
```

**Task:** Which stack appears for each filter?

---

<details><summary>Solution / expected output</summary>

```console
$ terramate list --tags networking
stacks/network

$ terramate list --tags app
stacks/app

$ terramate list --tags 'networking:shared'
stacks/network
```

A bare tag matches stacks that carry it. `tagA:tagB` is an AND expression — both
tags required. Path filters are unnecessary when tags are honest.

</details>

---

### Step 5 — Break → fix: missing `stack {}` → silent non-discovery

Break the app stack so the file exists but has **no** `stack {}` block:

```bash
printf '# broken — missing stack {}\n' > stacks/app/stack.tm.hcl
terramate list; echo "list exit: $?"
```

**Task:** Did Terramate error? Which stacks remain listed?

---

<details><summary>Solution / expected observation</summary>

```console
$ terramate list; echo "list exit: $?"
stacks/network
list exit: 0
```

**No error.** Exit `0`. `stacks/app` simply disappears from discovery. A missing
or non-`stack {}` file is silent non-discovery — the most common Day-3 footgun.

Fix by restoring the tracked contract (from the workshop checkout, or recreate):

```bash
# from inside "$demo" — restore from the workshop tree
cp "$OLDPWD/labs/day-3/21-stacks/stacks/app/stack.tm.hcl" stacks/app/stack.tm.hcl
# if $OLDPWD is wrong, use an absolute path to your checkout instead

terramate list
```

Expected after the fix:

```console
$ terramate list
stacks/app
stacks/network
```

Or recreate in place (must remove the broken file first —
`--ignore-existing` skips quietly and leaves the broken content):

```bash
rm -f stacks/app/stack.tm.hcl
terramate create stacks/app \
  --name app \
  --description 'Application workload' \
  --tags app,compute \
  --id 22222222-2222-2222-2222-222222222222 \
  --no-generate
terramate list
```

</details>

---

### Step 6 — Optional: leaf still validates as OpenTofu

Still inside `"$demo"`:

```bash
tofu -chdir=stacks/network init -backend=false -input=false
tofu -chdir=stacks/network validate -no-color
```

---

## Expected observations

- Flat leaves → empty `terramate list` (same as S20).
- `terramate create … --tags …` writes `stack.tm.hcl` and discovery lights up.
- `--tags` filters without hard-coding paths.
- A file without `stack {}` → **silent** non-discovery (exit `0`, stack omitted).
- OpenTofu still validates a leaf on its own.

## Cleanup / panic reset

```bash
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked tree under labs/day-3/21-stacks/ is never mutated by this lab
```

## Stretch

- From `"$demo"`, `tofu -chdir=stacks/app apply -auto-approve` (local provider —
  still no Docker). Confirm `app.marker` appears, then `tofu destroy -auto-approve`.
- Optional LocalStack: point a future S22/S23 leaf at LocalStack endpoints; this
  lab's `local` provider needs none.
- Peek ahead: add `after = ["network"]` under `stack` in `stacks/app/stack.tm.hcl`
  and re-list — ordering is S23; reset before leaving.

<details><summary>Solution / expected output</summary>

```console
Success! The configuration is valid.
```

Terramate discovery did not relocate state or invent a backend. Each stack
remains an ordinary OpenTofu root.

</details>

---

## Expected state / output

- Flat leaves → empty `terramate list` (same as S20).
- `terramate create … --tags …` writes `stack.tm.hcl` and discovery lights up.
- `--tags` filters without hard-coding paths.
- A file without `stack {}` → **silent** non-discovery (exit `0`, stack omitted).
- OpenTofu still validates a leaf on its own.

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
# tracked tree under labs/day-3/21-stacks/ is never mutated by this lab
```

Re-enter `labs/day-3/21-stacks/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- From `"$demo"`, `tofu -chdir=stacks/app apply -auto-approve` (local provider —
- Optional LocalStack: point a future S22/S23 leaf at LocalStack endpoints; this
- Peek ahead: add `after = ["network"]` under `stack` in `stacks/app/stack.tm.hcl`

Example verification from the workdir:

```bash
cd labs/day-3/21-stacks
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
