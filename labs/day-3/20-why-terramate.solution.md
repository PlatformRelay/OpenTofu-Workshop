# Lab 20 — Why Terramate — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-3/20-why-terramate/` unless a step says otherwise.

### Step 1 — Terramate on `PATH` (or a clear pointer)

From the repository root:

```bash
command -v terramate >/dev/null \
  || { printf '%s\n' "terramate not found on PATH — run: task setup"; exit 1; }
terramate version
```

**Task:** What version do you see? If the command is missing, what does the
script print?

---

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

### Step 2 — See the DRY pain in the tracked tree

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

---

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

### Step 3 — Initialise a disposable monorepo root

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

---

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

### Step 4 — Optional: prove one leaf still validates as OpenTofu

Still inside `"$demo"`:

```bash
tofu -chdir=stacks/network init -backend=false -input=false
tofu -chdir=stacks/network validate -no-color
```

**Task:** Does validate succeed without Terramate inventing a backend?

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

## Expected state / output

- Missing Terramate → explicit `task setup` pointer.
- `network` and `app` share identical `backend.tf` / `providers.tf` (DRY pain).
- After copy + `git init`, `terramate list` is empty until S21.
- OpenTofu still validates a leaf on its own; Terramate does not own state.

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
# return to the workshop checkout, then drop the disposable root
cd "$OLDPWD" 2>/dev/null || true
rm -rf "${demo:-}"
# tracked skeleton under labs/day-3/20-why-terramate/ is never mutated by this lab
```

If you experimented with `tofu apply` inside `"$demo"`, deleting that directory
removes any local state and markers. The repository workdir stays clean
(`.gitignore` already excludes `.terraform/`, `*.tfstate`, and `*.marker`).

Re-enter `labs/day-3/20-why-terramate/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- From `"$demo"`, run `terramate create stacks/network --name network` and

Example verification from the workdir:

```bash
cd labs/day-3/20-why-terramate
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
