# Facilitator runbook

Practical delivery notes for the **canonical three-day cut**
([`slides-3day.md`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/slides-3day.md)).
Pair with presenter notes on each slide and the
[scope and timing](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md#scope-and-timing-known-issue)
warning in the README.

**Shipped** = authored slides + lab (not a stub). All canonical sections
through **S26** are shipped; optional sections stay skippable via cut-order /
`hide:`.

| Day | Serve | Preflight |
| --- | --- | --- |
| Any | `task setup` then `task dev:3day` | `tofu version` ≥1.9; Docker (or k8s path) for LocalStack labs |
| 1–2 LocalStack labs | `task lab:up` before the first `localstack ✓` step | Health: <http://localhost:4566/_localstack/health> |
| 2 scanners | TFLint, Trivy, Checkov, Conftest on `PATH` | `task setup` optional Day-2 tools |
| 3 Terramate | Terramate on `PATH` (spoilers pinned ~0.17.x) | No Docker required for S20–S25 path |

**Custom cut:** for a single section or contiguous range instead of a full day deck,
use `pnpm deck -- --list`, then `pnpm deck -- --section S05` or
`pnpm deck -- --range S05-S09` (`task deck -- …`). `--dry-run` resolves IDs and
writes gitignored `.deck-selection.md` without starting Slidev. Without a TTY and
`gum`, pass an explicit selector — the launcher never falls back to the superset.
See [AGENT.md](../AGENT.md) · facilitator launcher.

---

## The evolving project: `service-manifest`

Every hands-on stage grows **one** project — `service-manifest` — so a learner
who asks "why are we doing this?" can be answered with "you are extending what
you built last session". The name is the child module in the tree at
`labs/day-1/07-modules/modules/service-manifest/`; `svc-manifest` is informal
shorthand for the same thing. The [syllabus](syllabus.md) holds the **canonical**
stage map and the full rationale — this table is a delivery-side copy; edit the
syllabus first.

Stage numbers below are the teaching sequence, and since the Day-1 resequencing
landed (US-C-RESEQ) they **match delivery order**: Day 1 runs
S00 → S01 → S02 → S03 → S06 → S15 → S04 → S05 → S07 → S08. Section IDs never
change, so the IDs are not consecutive — read the stage column, not the number.

**Stage adjacency is now delivery adjacency.** A room reaching S04 (stage 6) has
already seen stages 4–5 (variables, guards). The cut-order below is the same
sequence with the fit-plan skips applied.

**Where each concept is introduced:** `resource` → stage 0 · `variable` →
stage 2 (block taxonomy; first appears as a feature switch at stage 0b; typed,
validated and sensitive at stage 4) · `output` → stage 2 (block taxonomy; first
appears in the stage-1 lab config) · `plan` → stage 0 (read line by line at
stage 3) · `apply` → stage 0 (full lifecycle at stage 3) · state → stage 6
(named at stage 0, motivated at stage 3) · modules → stage 8 · testing → stage 10
(`tofu test` with `mock_provider` first taught at stage 9) · CI → stage 14.

| Stage | Section | Workdir | Introduces |
| --- | --- | --- | --- |
| 0 | S00 · Welcome & setup | `labs/day-1/00-setup/` | **`resource`**, `init`, the first **`plan`** and **`apply`** |
| 0b | S00 · stretch | `labs/day-1/00-setup/` | the first cloud-shaped resource (S3 on LocalStack), gated by the first `variable` — a `bool` feature switch |
| 1 | S01 · Infrastructure as Code | `labs/day-1/01-iac-fork/` | declarative vs imperative — the lab config surfaces its first `output`, though the block type is taught at stage 2 |
| 2 | S02 · HCL & building blocks | `labs/day-1/02-hcl-blocks/` | the block taxonomy — **`variable`**, **`output`**, `locals`, `data`, references (`module` is only a forward reference to stage 8) |
| 3 | S03 · The core workflow | `labs/day-1/03-core-workflow/` | the four-command loop — **plan diffs**, the graph, `destroy`, and *why* state exists |
| 4 | S06 · Variables, validation & types | `labs/day-1/06-variables/` | **typed, validated and sensitive `variable`s** — the project's own inputs |
| 5 | S15 · Validation, preconditions & checks | `labs/day-1/15-conditions-checks/` | `precondition`, `postcondition`, `check` |
| 6 | S04 · State | `labs/day-1/04-state/` | **state**, drift, backends |
| 7 | S05 · State encryption | `labs/day-1/05-state-encryption/` | encrypted state and encrypted plan |
| 8 | S07 · Modules | `labs/day-1/07-modules/` | **`module`** — `./modules/service-manifest` consumed twice |
| 9 | S08 · Naming & labelling module | `examples/naming-labels-demo/` | one naming + labelling taxonomy — and the first `tofu test` run, with an aliased `mock_provider` |
| 10 | S12, S13 | `labs/day-2/12-testing-pyramid/`, `13-static-analysis/` | **testing as a discipline** — the pyramid, `fmt`, TFLint, pre-commit |
| 11 | S14 · Security & policy scanners | `labs/day-2/14-security-scanners/` | policy + security scanning (planted insecure fixture — deliberately *not* the learner's project) |
| 12 | S16, S17 | `labs/day-2/16-tofu-test/`, `17-mocking/` | `tofu test` in depth — apply vs plan runs, and mocking beyond stage 9's first taste |
| 13 | S18 · Integration, e2e & cost | `labs/day-2/18-terratest-cost/` | integration + cost (optional tier) |
| 14 | S19 · Testing in CI/CD | `labs/day-2/19-testing-cicd/` | **CI** — the whole ladder as pipeline jobs |
| 15 | S20–S26 | `labs/day-3/**`, `examples/capstone/` | stacks → codegen → ordering → filtering → capstone |

**S09, S10 and S11 carry no stage number** — the fit plan skips S09 and S10, and
S11 is hidden in the 3-day cut, so all three sit outside the **Day-1** stage
sequence. Skippable does not mean unstaged elsewhere: S18 is hidden yet holds
stage 13, and S25 sits inside stage 15's span. If you do run S09, its
`local_file.manifest` is the same project spine, not a new example.

**What carries forward.** Labs do not share one mutating directory — each runs
standalone from its own tracked workdir (`task lab:validate DIR=…`), and the
drift gate byte-compares a slide block against a **whole** file, so there is no
snapshot for a mutating directory to cite. Continuity is carried by addresses:

- **Project spine — never renamed, never silently dropped:**
  `local_file.manifest`, `variable "service"`, `variable "environment"`,
  `output "manifest_path"`.
- **Auxiliary demo resources** (e.g. `local_file.summary`, `random_pet.env`) may
  retire — and `random_pet.env` even returns at stage 5 — but the lab preamble
  says so every time. If a learner asks where something went, the preamble has
  the answer; if it does not, that is a defect worth filing.

**Do not tell the room "each lab is the last one plus more".** It is not true of
the tree: **six of the seven** Day-1 transitions drop material (2→3, 3→4, 4→5,
5→6, 6→7, 7→8 — only 1→2 retires nothing), and S04/S05 teach deliberately
against a small config. Say instead: the spine carries forward, and anything
retired is named — every lab's `### Continuity` preamble lists what the previous
stage left behind and why, so that is your answer when someone asks. Stage 8 is
the one place the spine is not at the root: S07 *extracts* it into
`./modules/service-manifest`, so the addresses become
`module.checkout.local_file.manifest` and friends. Details in the
[syllabus](syllabus.md).

---

## Live cut-order

Budget is **390 min/day** (6.5 h, ~50/50 explain-then-run). The authoritative
planning totals for the canonical cut — **slides *and* labs**, computed by
`canonicalDayTotals()` in `scripts/deck-manifest.mjs` — are published here and in
the
[README](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md#published-day-totals):

| Day | Slides | Labs | Slides+labs (planned) | Against the 390 budget |
| --- | ---: | ---: | ---: | --- |
| 1 | 535 | 245 | **780** | **+390 over** |
| 2 | 180 | 180 | 360 | 30 under |
| 3 | 200 | 200 | **400** | **+10 over** |

**Day 1 and Day 3 do not fit.** Say so when you plan the delivery: the honest
statement is "Day 1 is 390 over a one-day budget", not "Day 1 fits once you apply
the fit plan". These are **unrehearsed planning estimates** from section
frontmatter and lab headers — no rehearsal has timed them, so treat them as a
budget, not a stopwatch.

The README fit plan's **400 is a different figure**: it is Day-1 **slide**
runtime only (`dayOneFitTotal()`), compressed from 665. Day-1 lab time (245) is
untouched by it, so a fit-plan Day 1 still runs **645** of slides+labs. Use 400
to check the deck against the day; use 780 to plan the day itself. Note that 400
does not fit either: since S01 grew, the compressed deck is 10 minutes over the
390 budget before a single lab runs.

### Day 1 (author → guard → package)

**Standard delivery order** (core path after fit-plan skips):

`S00 → S01 → S02 → S03 → S06 → S15 → S04 → S05 → S07 → S08`

| Priority | Action | Source |
| --- | --- | --- |
| 1 | Skip **S11** (optional; already `hide: true`) | README fit plan row 1 (−35) |
| 2 | Skip **S10**, then **S09** at their `DAY1-FIT` markers | README rows 2–3 (−45, −50) |
| 3 | Compress S00–S03, S06, S15, S04, S05, S07 at markers until slide time is ≤400 | README rows 4–12 |
| Keep | **S08** at 65 min — flagship synthesis | `slides-3day.md` marker |

Cut optional → recommended → compress core. Never drop S08 or S15's blocking
`precondition` + `check` beat when compressing.

**The Day-1 resequencing was timing-neutral.** Moving S06 and S15 ahead of S04
and S05 changed no section's length, so it left the planning total and every
fit-plan row exactly as they were before the reorder — only the order changed.
What did move the total was S01 growing 40→50 minutes to carry the
design-principles and alternatives beats: Day 1 is now **780** planned, and the
fit-plan slide target is **400**.

**Accepted cost of the canonical cut: `for_each` is never taught.** S09 and S10
are both skipped, which removes S09's `count` vs `for_each` lesson (and
`moved`-based refactoring without replacement) and S10's provider-level
`for_each` / `-exclude`. A canonical-cut learner meets the keyword only
incidentally — a `dynamic` block toggle in the Day-3 capstone's provider
boilerplate, and an optional stretch prompt at the end of Lab 07 — and is never
taught or checked on it. This is deliberate, not an oversight; S09 is the first
section to restore when time returns.

### Day 2 (test)

Canonical visible order: `S12 → S13 → S14 → S16 → S17 → S19`.

| Priority | Action |
| --- | --- |
| Skip first | **S18** (optional; already `hide: true`) — Terratest/Infracost tip |
| If short | Shorten explain on S12; keep S13→S14→S16 chain intact |
| Keep | S17 mock path (Docker-down proof) and S19 `fmt -check` false-green |

#### The tooling ladder — reached by cross-reference, not by promotion

Three tools sit off the canonical Day-2 path: `terraform-docs` and Gitleaks in
[S28 · Ecosystem tooling](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/pages/S28-ecosystem-tooling/index.md)
(optional, Day 3), Infracost in
[S18 · Integration, e2e & cost](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/pages/S18-integration-cost/index.md)
(optional, Day 2). Rather than promote either section,
the canonical sections point at them, so the ladder reads as one progression at
no cost to the day:

| Cross-reference | Points at | What the facilitator says |
| --- | --- | --- |
| S12 → S15 | Day-1 `precondition` / `postcondition` / `check` | S15 is **rung 0** — assertions inside the configuration, beneath the pyramid's base |
| S13 → S28 | `terraform_docs` + `gitleaks` hooks in `.pre-commit-config.yaml` | Gitleaks **already runs** in the learner's own `pre-commit run --all-files` (golang hook, binary provisioned); `terraform_docs` is a script hook needing `terraform-docs` on `PATH` — a **one-time install** ([Lab 28](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/28-ecosystem-tooling.md)). S28 is their home beat |
| S19 → S18 | S18's Infracost beat | A **signpost to optional material** — S18 is outside the canonical cut, so cost is *not* covered on the three-day path |

**Why not just promote a tier?** Tier alone would not have pulled S18 in: the
generated `slides-day-2.md` selects on `section.canonical`, and S18 is
`canonical: false`. Including it would mean flipping that flag, which adds its
30 slide + 30 lab minutes — **60 minutes** — to a Day 2 whose planning estimate
already stands at 360 against a 390 min/day budget, i.e. roughly 30 minutes of
headroom. Sixty into thirty does not go, so the cross-reference route was chosen
and no tier, `canonical` or `hide` value was changed. The same reasoning applies
to S28, which stays a Day-3 optional appendix.

### Day 3 (scale)

Canonical visible order: `S20 → S21 → S22 → S23 → S24 → S26` (+ optional S25).

| Priority | Action |
| --- | --- |
| Ship | S20 → S21 → S22 (generate) → S23 (order) → S24 (`--changed` / `--tags`) → **S26** capstone |
| If short | Skip **S24** (recommended) — deepen S23 Q&A; keep core S20–S23; **keep S26** wrap if at all possible |
| Optional | **S25** (`hide: true` in 3-day cut) — `--changed` CI + Cloud overview; skip unless time |
| Optional | **S27** (`hide: true` in 3-day cut) — Terragrunt vs Terramate appendix; **skip first**, run only on audience demand after S26 (never as required Day-3 time) |
| Optional | **S28** (`hide: true` in 3-day cut) — ecosystem tooling survey (tenv, terraform-docs, pre-commit); **skip first**, run only on audience demand after S26 (never as required Day-3 time) |
| Keep | **S26** — drives `examples/capstone/`; Associate table is a design check, not exam prep ([full appendix](associate-alignment.md)) |

---

## Panic reset — LocalStack crash mid-lab (~5 min)

Use when `:4566` dies, health flips unhealthy, or apply errors smell like a
stale emulator (connection refused, empty service list, auth-token exit).

1. **Stop talking; freeze the room** — “Pause on the current step; spoilers stay
   closed.” (~30 s)
2. **Wipe the emulator:** from the repo root,
   `task lab:down && task lab:up`  
   Wait for healthy on `:4566` (compose healthcheck; typically under a minute).
   No Docker? `task lab:down:k8s && task lab:up:k8s`. (~2–3 min)
3. **Learner workdir:** `tofu destroy -auto-approve` in the active lab/example
   directory if state still points at dead resources; else delete local
   `terraform.tfstate*` and re-`init` only if the lab says so. (~1 min)
4. **Rejoin the beat:** re-run the last green step from the lab, then continue.
   Panic reset text in every lab matches `task lab:down` (+ destroy where
   needed). (~1 min)

`PERSISTENCE=0` means every down/up is a **clean slate** — say that out loud so
nobody hunts for “their” bucket from before the crash. Detail:
[`setup/localstack.md`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/setup/localstack.md).

---

## Known failure modes

| Symptom | Likely cause | Facilitator fix |
| --- | --- | --- |
| `task lab:up` times out | Docker daemon down / starved | Start Docker; `docker compose logs localstack`; or switch to `task lab:up:k8s` |
| LocalStack exits wanting `LOCALSTACK_AUTH_TOKEN` | CalVer / `:latest` image | Pin **`localstack/localstack:4.9.2`** everywhere (compose, k8s, CI) |
| Connection refused on `:4566` | Not healthy yet / crashed | Wait for health URL; then panic-reset path above |
| State / resources “missing” after restart | Expected with `PERSISTENCE=0` | Re-apply from lab step; do not chase old IDs |
| Docker disk / memory pressure | Many images; Terratest profile pull | `docker system df`; prune unused; don’t `lab:up` the terratest profile by accident |
| `task verify` fails on macOS bash | `/bin/bash` 3.2 first on `PATH` | Put `/opt/homebrew/bin` or `/usr/local/bin` first (Bash ≥4) |
| Lab 03 `init` says “Reusing previous version…” instead of “created a lock file” | `task verify` validates every lab workdir (US-C-GATE), seeding `.terraform/` + `.terraform.lock.hcl` there | Clear the lab before rehearsing or delivering it: `git clean -Xfd labs/day-1/03-core-workflow` (any lab dir) — Step 3 teaches the FIRST-init output |
| `bash scripts/verify.sh` reds with `init failed` + `there is no package for registry.opentofu.org/… cached in .terraform/providers`, in a **different lab directory each time** | A **cold provider cache** — the first run after `git clean -Xfd labs` wiped every `.terraform/` — or, less often, another `tofu` writing the same dirs concurrently. Every instance observed while writing this row was the cold cache, with `ps` showing no second run; that is an observation from one dev host, not a measured frequency | Re-run `verify` once, on its own: **the first run after a clean is not a result, the second one is**. The varying directory is the signature — it is not a defect in whatever you just changed. verify.sh names both causes in the failure itself |
| `another verify.sh is already running in this checkout — refusing to start` (exit 2) | Two runs at once in one checkout. Since US-C-GATE the gate runs `tofu init` **in place** in every Day-1/Day-3 lab workdir, so both would write the same `.terraform/` | Wait for the other run, or use a separate checkout. Exit **2** means the gate declined to run and certified nothing (exit 1 means it ran and found problems). If no such process exists, the lock is stale — the refusal message prints its **absolute** path, so use that rather than a bare `rm -rf .verify.lock`, which does nothing from a lab subdirectory — though verify.sh breaks stale locks itself when the recorded pid is gone |
| `pnpm link-check` reds with dozens of `missing internal target .github/SUPPORT.md` under `labs/**/.terraform/providers/…/README.md` | Same root cause as the two rows above: `verify` seeds `.terraform/` in every lab workdir, and `scripts/link-check.mjs` walks **all** `.md` under `labs/` with no exclusions — so it checks the vendored provider READMEs | Inert, and nothing to do with your docs. `git clean -Xfd labs`, then re-run `link-check`. **This is why the gate order is `git clean -Xfd labs` → `link-check` → `verify`**: run `verify` first and `link-check` reds every time |
| Tool-version drift vs spoilers | Newer tofu / scanners / Terramate | Spoilers are captured pins — accept output shape drift; re-run `task setup`; do not improvise unpinned `:latest` |
| Day-2 scanner missing | Optional toolchain not installed | `task setup`; install TFLint / Trivy / Checkov / Conftest before S13–S14 |
| Terramate `list` empty | No `stack {}` yet (S20) or missing block (S21 break) | Teaching moment — silent non-discovery; don’t “fix” ahead of the lab |
| Terramate `cycle detected` | Mutual `after`/`before` (S23 break) | Teaching moment — read the path; remove one edge; don’t add a third stack |
| Terramate `repository has uncommitted files` | Dirty worktree + `run --changed` (S24) | Teaching moment — `list --changed --why` still works; commit (identity pin) or discard |
| `--changed` needs two commits | Learner stuck on baseline-only `main` | Expected — branch + second commit before `--changed` |
| `--changed` fails in Actions / shallow clone | Missing `fetch-depth: 0` (S25) | Teaching moment — default checkout depth breaks change detection |
| Capstone passphrase / encryption errors | `state_passphrase` < 16 chars or unset | Export `TF_VAR_state_passphrase` (≥16); lab Step 2 is the deliberate break |
| Capstone SQS apply slow / hangs | LocalStack SQS create latency; AWS provider ≥6 | Wait ~30 s; keep AWS provider `< 6.0` (pinned in `providers.tf`) |
| Half-applied capstone residue | Crash mid-apply | Panic reset: `destroy` + delete local state + `task lab:down` (lab Step 6) |

---

## Shipped sections

Timing legend: **Full (fit plan)** = the section's uncompressed **slide**
minutes, the figure the README fit plan compresses — explain time only.
**Lab** = `duration:` on the lab slide / lab header; add the two for the section's
share of the day. **3-day cut** = compress / skip from the fit plan or `hide:` in
`slides-3day.md`. All minutes are unrehearsed planning estimates.

### Day 1

| ID | Topic | Tier | Full (fit plan) | Lab | 3-day cut | Checkpoint (ask before moving on) | Watch-outs |
| --- | --- | --- | ---: | ---: | --- | --- | --- |
| S00 | Welcome & setup | core | 40 → **25** | 20 | Compress | Can everyone `tofu apply` local + reach LocalStack health? | First LocalStack boot; Docker not running |
| S01 | Infrastructure as Code | core | 50 → **30** | 20 | Compress | Declarative vs imperative — what does the plan give you that a script doesn’t? | Fork timeline is pre-reading when compressed; keep the six design principles and the alternatives beat |
| S02 | HCL & building blocks | core | 50 → **35** | 20 | Compress | Name the six block types; which one alone mutates the world? | Reference wiring; `.tofu` vs `.tf` aside |
| S03 | Core workflow | core | 60 → **45** | 20 | Compress | Read a plan line: `+` / `~` / `-` and “known after apply”? | One lifecycle run when compressed |
| S06 | Variables & types | core | 50 → **35** | 25 | Compress | Break a validation on purpose — which phase fails? | Precedence variants follow-up when compressed |
| S15 | Preconditions & checks | core | 50 → **35** | 30 | Compress | Which guards fail at plan vs apply? What is `check` for? | Keep one blocking condition + `check` |
| S04 | State | core | 50 → **35** | 20 | Compress | Why is `terraform.tfstate` a secret store even when the CLI redacts? | Backend migration is follow-up when compressed |
| S05 | State encryption | core | 60 → **45** | 25 | Compress | Prove ciphertext on disk; what does `enforced = true` change? | PBKDF2 lab key handling; fallback migrate |
| S07 | Modules | core | 60 → **50** | 35 | Compress | What is the module contract (inputs/outputs)? Demo registry/OCI only | No registry network on runnable path |
| S08 | Naming & labelling | core | **65** | 30 | Keep | Mock plan green, then LocalStack apply — validation enforces convention? | Step 4 needs LocalStack; panic-reset safe |
| S09 | Best practices | recommended | 50 | 30 | **Skip** | (If run) `count` vs `for_each` — which rebuilds on middle removal? | Only if time returns |
| S10 | Differentiators | recommended | 45 | 25 | **Skip** | (If run) Provider `for_each` / `-exclude` — needs live LocalStack | Heavy emulator use |
| S11 | TACO landscape | optional | 35 | 20 | **Skip** (`hide`) | (If run) Constraints-first platform pick — paper only | No tooling |

### Day 2

| ID | Section | Tier | Lab | 3-day cut | Checkpoint | Watch-outs |
| --- | --- | --- | ---: | --- | --- | --- |
| S12 | Testing pyramid | core | 20 | Keep | Cheapest signal that can expose *this* risk? | Classification before tools |
| S13 | Static analysis | core | 30 | Keep | Format → validate → lint — what did each catch? | TFLint required |
| S14 | Security scanners | core | 35 | Keep | Trivy vs Checkov vs Conftest — who caught `cost_center`? | Pinned scanner versions in spoilers |
| S16 | `tofu test` | core | 35 | Keep | Plan vs apply run — when is apply justified? | LocalStack for apply tests |
| S17 | Mocking providers | core | 30 | Keep | Green while Docker/LocalStack is **down**? | Prove emulator idle on purpose |
| S18 | Integration & cost | optional | 30 | **Skip** (`hide`) | (If run) Container Terratest lane; Infracost optional key | Do not pull terratest on `lab:up` |
| S19 | Testing in CI/CD | recommended | 30 | Keep | Why is `fmt` without `-check` a false green? | Paper + fixture; badge honesty |

### Day 3 (shipped)

| ID | Section | Tier | Lab | 3-day cut | Checkpoint | Watch-outs |
| --- | --- | --- | ---: | --- | --- | --- |
| S20 | Why Terramate | core | 25 | Keep | Does Terramate manage state? (Answer: **no**.) | Disposable git root; empty `list` expected |
| S21 | Stacks | core | 30 | Keep | Why did a directory vanish from `terramate list`? | Silent skip without `stack {}` |
| S22 | Code generation | core | 30 | Keep | What restores a hand-edited `_backend.tf`? | `terramate generate`; detailed exit `2` |
| S23 | Orchestration | core | 30 | Keep | Why does plain `list` disagree with `--run-order`? | Cycle fail-closed; one `after` edge enough |
| S24 | Change detection | recommended | 25 | Keep / skip if short | Prove only the changed stack runs — what did network do? | Dirty `run --changed`; two-commit baseline; identity pin |
| S25 | Terramate CI + Cloud | optional | 25 | **Skip** (`hide`) unless time | Does the PR gate use `--changed`? Does Cloud manage state? (**no**) | Paper fixture; `fetch-depth: 0`; **no Cloud signup**; restore planted YAML |
| S26 | Capstone & wrap-up | core | 60 | Keep | Can the room green the unit lane and clean up with `lab:down`? Associate table = design check? | Drive `examples/capstone/` (no rewrite); short-passphrase break; panic-reset no residue; Terramate stretch optional |
| S27 | Terragrunt vs Terramate | optional | 20 | **Skip** (`hide`) — appendix | (If run) Does `remote_state` host state? (Answer: **no** — it generates `backend.tf`.) | Read-only fixture, no Terragrunt install; ~40 min total incl. lab; restore planted claim (`git restore`) |
| S28 | Ecosystem tooling | optional | 20 | **Skip** (`hide`) — appendix | (If run) Does a fixing hook block the commit? (Answer: **fails the run and repairs the file** — the rerun is green.) | Needs `pre-commit` + one-time network hook fetch — else demo-only; `PCT_TFPATH` export; tenv/terraform-docs steps read-only; ~40 min total incl. lab |

---

## Facilitator checklist (each morning)

1. `task setup` — required tools green; Day-2/3 optionals as needed.
2. `task lab:up` once if any LocalStack lab is on today’s cut; confirm health URL.
3. Open `task dev:3day` presenter mode; skim today’s cut-order markers.
4. Know the panic-reset path cold before the first emulator lab.
5. End of day: `task lab:down` so tomorrow starts clean.
