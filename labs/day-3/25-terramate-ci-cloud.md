# Lab 25 — Terramate in CI + Cloud

| | |
| --- | --- |
| **Section** | S25 — Terramate in CI + Cloud |
| **Environment** | `mock ✓ (paper + fixture · no docker)` |
| **Estimated time** | 25 min |

## Objective

Repair a **PR workflow** so it uses **`fetch-depth: 0`** and
**`terramate run --changed`**, then prove the same selection locally on a
feature branch (S24 shape). Review **Terramate Cloud** as a
**read-only / conceptual** observability layer — **no signup** for the
core lab. Repeat: Terramate **still does not manage state**.

No Docker, no GitHub Actions runner, no cloud account required.

## Prerequisites

- Lab 24 completed conceptually (`--changed` / dirty-worktree).
- OpenTofu ≥1.8 (`tofu version`).
- Terramate on `PATH` (`task setup` / `bash setup/bootstrap.sh`).
- A terminal at the repository root.
- Optional: `actionlint` on `PATH` for YAML validation.

## Files used

- [`labs/day-3/25-terramate-ci-cloud/`](./25-terramate-ci-cloud/) — Day-3
  monorepo workdir (S24 stacks **plus** a paper CI fixture). Copy into a
  disposable directory for the git steps; never mutate the tracked tree
  except when editing the fixture YAML as the lab directs.
- [`.github/workflows/terramate-pr.yml`](./25-terramate-ci-cloud/.github/workflows/terramate-pr.yml)
  — incomplete lab fixture you will repair (not executed by this repo’s CI).
- [`terramate.tm.hcl`](./25-terramate-ci-cloud/terramate.tm.hcl) — Git change
  baseline on `main` (slide ↔ lab source of truth).

Root config (tracked):

<!-- source: labs/day-3/25-terramate-ci-cloud/terramate.tm.hcl -->
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

---

## Step 1 — Terramate on `PATH`

From the repository root (pin an absolute path for later cleanup — nested
`cd` into disposable demos must not rely on `$OLDPWD`):

```bash
repo_root="$(pwd)"
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

Any current 0.14+ build is fine.

</details>

---

## Step 2 — Spot the planted defects

Open the fixture:

```bash
sed -n '1,80p' labs/day-3/25-terramate-ci-cloud/.github/workflows/terramate-pr.yml
```

**Task:** Name two defects relative to a change-detection-driven PR gate.

<details><summary>Solution / expected observation</summary>

1. **Shallow checkout** — `actions/checkout@v4` has no `fetch-depth: 0`.
   Default depth is `1`, so the runner may lack history to compare against
   `default_branch = "main"`.
2. **No `--changed`** — the job runs `terramate list --run-order` and
   `terramate run -- tofu …`, which walks the **whole fleet** on every PR.

</details>

---

## Step 3 — Repair the workflow (paper)

Edit the tracked fixture so the PR job:

1. Checks out with `fetch-depth: 0`.
2. Lists with `terramate list --changed`.
3. Runs `tofu init` / `tofu plan` only via `terramate run --changed`.

Keep the Terramate and OpenTofu install pins. OpenTofu-first: the command
after `--` is **`tofu`**, not `terraform`.

<details><summary>Solution / expected file</summary>

Replace
`labs/day-3/25-terramate-ci-cloud/.github/workflows/terramate-pr.yml` with:

```yaml
# Paper fixture — repaired PR gate for Lab 25.
# Not executed by the workshop repository's GitHub Actions.

name: Terramate PR (lab fixture)

on:
  pull_request:
    branches: [main]

concurrency:
  group: terramate-pr-${{ github.ref }}
  cancel-in-progress: true

jobs:
  plan-changed:
    name: Plan changed stacks
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install Terramate
        uses: terramate-io/terramate-action@v3
        with:
          version: "0.17.1"

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: "1.10.3"
          tofu_wrapper: false

      - name: List changed stacks
        run: terramate list --changed

      - name: Init and plan changed stacks
        # Unguarded — matches the S25 slide. A plain `run:` step does NOT set
        # steps.*.outputs.stdout; gating on that would skip plan forever.
        run: |
          terramate run --changed -- tofu init -input=false
          terramate run --changed -- tofu plan -input=false -no-color
```

Validate YAML shape when `actionlint` is available:

```bash
actionlint labs/day-3/25-terramate-ci-cloud/.github/workflows/terramate-pr.yml
```

`actionlint` exit `0` with no findings is enough for this paper lab. If the
binary is missing, skip — the spoiler YAML above is the taught shape.

</details>

---

## Step 4 — Prove `--changed` locally (same command CI will run)

Copy the workdir into a disposable git root. Pin learner identity on
**every** commit (same one-shot pattern as S20–S24 — bare `git commit` is
wrong).

```bash
demo="$(mktemp -d)"
cp -R "$repo_root/labs/day-3/25-terramate-ci-cloud/." "$demo/"
cd "$demo"
git init -q
git checkout -q -b main
git add -A
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'baseline stacks for CI lab'
git checkout -q -b feature/change-app
cat > stacks/app/main.tf <<'EOF'
resource "local_file" "marker" {
  filename = "${path.module}/app.marker"
  content  = "app-ci-v2\n"
}
EOF
git add stacks/app/main.tf
git -c user.email=learner@example.invalid -c user.name=Learner \
  commit -qm 'change app for PR gate demo'
terramate list --changed --why
terramate run --changed -- echo ONLY_APP
```

**Task:** Which stacks does `--changed` select? Does a full dry-run still
enter network?

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
terramate: (dry-run) Entering stack in /stacks/app
```

**Only `stacks/app`** is selected by `--changed` — the same filter the
repaired workflow runs. A full run still walks network then app (S23 order).

Optional OpenTofu (still mock, no Docker):

```bash
terramate run -- tofu init -input=false
terramate run --changed -- tofu plan -input=false -no-color
```

Only `/stacks/app` should print a plan.

</details>

---

## Step 5 — Break → fix: shallow history cannot see `main`

Still inside `"$demo"` on `feature/change-app`, simulate a shallow clone’s
blind spot by pointing change detection at a base that is **not** in the
shallow tip’s ancestry view — or simply document the CI footgun with a
local clone mirror:

```bash
shallow="$(mktemp -d)"
git clone --depth 1 "file://$demo" "$shallow/repo"
cd "$shallow/repo"
terramate list --changed --why; echo "exit: $?"
```

**Task:** Why does change detection struggle (or refuse) on a depth-1 clone?
What does the repaired workflow set to avoid this in Actions?

<details><summary>Solution / expected observation</summary>

Spoilers captured when cloning the feature tip with `--depth 1` (only the
tip commit is present — `main` is absent):

```console
$ terramate list --changed --why; echo "exit: $?"
Error: flag --changed requires a repository with at least two commits
exit: 1
```

A shallow clone lacks the history (and often the `main` ref) needed to
diff against `default_branch`. That is why CI must not use the default
`fetch-depth: 1`.

The repaired workflow sets:

```yaml
with:
  fetch-depth: 0
```

so the runner has full history for change detection. Fix in CI is always
`fetch-depth: 0` (or an equivalent full fetch) — never “hope the default
is deep enough.”

Return to the disposable demo and discard the shallow tree:

```bash
cd "$demo"
rm -rf "$shallow"
```

</details>

---

## Step 6 — Terramate Cloud (read-only / no signup)

**Do not** create a Terramate Cloud account for this lab.

From the slides / facilitator talk-track, answer in your notes:

1. Name **three** Cloud concerns (e.g. drift, misconfiguration, run
   observability).
2. Does Cloud **manage state**? (Expected: **no**.)
3. Can the core PR gate (`--changed` + `tofu plan`) run **without** Cloud?

<details><summary>Solution / expected observation</summary>

1. **Drift detection**, **misconfiguration / policy signals**, and
   **stack / run observability** (dashboards over CI runs). Exact product
   labels may shift — the category is observability SaaS on top of the OSS
   CLI.
2. **No.** Terramate Cloud does **not** manage state. Backends, locks, and
   encryption stay with **OpenTofu** (same S20 non-negotiable).
3. **Yes.** The repaired GitHub Actions fixture is **CLI-only**. Cloud sync
   flags are optional add-ons, not required for the gate.

</details>

---

## Expected observations

- A PR workflow without `--changed` plans the whole monorepo — expensive and
  noisy.
- `fetch-depth: 0` is mandatory for Git change detection in Actions.
- Local `terramate run --changed` matches the CI command after `--`.
- Terramate Cloud is optional observability — **no signup** for core lab.
- Terramate **still does not manage state**.

## Cleanup / panic reset

Restore the lab fixture workflow (planted defects must stay in the tracked
tree for the next cohort):

```bash
cd "${repo_root:?set repo_root in Step 1}"
rm -rf "${demo:-}" "${shallow:-}"
git restore -- labs/day-3/25-terramate-ci-cloud/.github/workflows/terramate-pr.yml
git status --short -- labs/day-3/25-terramate-ci-cloud
```

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-3/25-terramate-ci-cloud` prints nothing.
Disposable demo directories are gone. The fixture again shows the planted
shallow-checkout and missing-`--changed` defects.

</details>

## Stretch

- Inside `"$demo"`, run the exact plan line from the repaired workflow:

  ```bash
  terramate run --changed -- tofu plan -input=false -no-color
  ```

- Peek at upstream docs for `terramate-io/terramate-action` — note Cloud sync
  flags (`--sync-deployment`, `--sync-drift-status`) are **out of scope**
  for the core lab (they need a tenant). Reset before leaving.
