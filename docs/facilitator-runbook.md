# Facilitator runbook

Practical delivery notes for the **canonical three-day cut**
([`slides-3day.md`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/slides-3day.md)).
Pair with presenter notes on each slide. The scope-and-timing arithmetic —
the published day totals and the executable Day 1 fit plan — lives in
[Live cut-order](#live-cut-order) below; the README keeps only the headline
[scope and timing](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md#scope-and-timing-known-issue)
warning.

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
See the [authoring guide](authoring-guide.md#repository-map) · facilitator launcher.

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
S00 → S01 → S02 → S03 → S06 → S15 → S04 → S05 → S07 → S08 → S09. Section IDs never
change, so the IDs are not consecutive — read the stage column, not the number.

**Stage adjacency is now delivery adjacency.** A room reaching S04 (stage 6) has
already seen stages 4–5 (variables, guards). The cut-order below is the same
sequence with the fit-plan skips applied.

**Where each concept is introduced:** `resource` → stage 0 · `variable` →
stage 2 (block taxonomy; first appears as a feature switch at stage 0b; typed,
validated and sensitive at stage 4) · `output` → stage 2 (block taxonomy; first
appears in the stage-1 lab config) · expressions (conditionals, `for`,
functions, indexing) → stage 2 (first used by the stage-0b feature switch) ·
`plan` → stage 0 (read line by line at stage 3) · `apply` → stage 0 (full
lifecycle at stage 3) · `depends_on` → stage 3 (only for a dependency no
reference expresses) · state → stage 6
(named at stage 0, motivated at stage 3) · `import` → stage 6 (adopting an
existing bucket on LocalStack; `data`, a block type since stage 2, returns there
as the read-only alternative) · modules → stage 8 · `count` vs
`for_each` → stage 9b (`count` first appears as a `0`/`1` feature switch at
stage 0b) · `dynamic` → stage 9b · `lifecycle` → stage 9b · `moved`/`removed` →
stage 9b · testing → stage 10 (`tofu test` with `mock_provider` first taught at
stage 9) · CI → stage 14.

| Stage | Section | Workdir | Introduces |
| --- | --- | --- | --- |
| 0 | S00 · Welcome & setup | `labs/day-1/00-setup/` | **`resource`**, `init`, the first **`plan`** and **`apply`** |
| 0b | S00 · stretch | `labs/day-1/00-setup/` | the first cloud-shaped resource (S3 on LocalStack), gated by the first `variable` — a `bool` feature switch |
| 1 | S01 · Infrastructure as Code | `labs/day-1/01-iac-fork/` | declarative vs imperative — the lab config surfaces its first `output`, though the block type is taught at stage 2 |
| 2 | S02 · HCL & building blocks | `labs/day-1/02-hcl-blocks/` | the block taxonomy — **`variable`**, **`output`**, `locals`, `data`, references, **expressions** in `tofu console` (`module` is only a forward reference to stage 8) |
| 3 | S03 · The core workflow | `labs/day-1/03-core-workflow/` | the four-command loop — **plan diffs**, the graph, `destroy`, and *why* state exists |
| 4 | S06 · Variables, validation & types | `labs/day-1/06-variables/` | **typed, validated and sensitive `variable`s** — the project's own inputs |
| 5 | S15 · Validation, preconditions & checks | `labs/day-1/15-conditions-checks/` | `precondition`, `postcondition`, `check` |
| 6 | S04 · State | `labs/day-1/04-state/` | **state**, drift, backends, **`import`** (adopt an existing bucket; `data` as the read-only alternative) |
| 7 | S05 · State encryption | `labs/day-1/05-state-encryption/` | encrypted state and encrypted plan (optional Step 6: `aws_kms` key provider on LocalStack) |
| 8 | S07 · Modules | `labs/day-1/07-modules/` | **`module`** — `./modules/service-manifest` consumed twice |
| 9 | S08 · Naming & labelling module | `examples/naming-labels-demo/` | one naming + labelling taxonomy — and the first `tofu test` run, with an aliased `mock_provider` |
| 9b | S09 · Best practices | `labs/day-1/09-best-practices/` | **`count` vs `for_each`**, `dynamic` blocks, the `lifecycle` meta-arguments, and `moved`/`removed` refactoring — the spine's `local_file.manifest` fanned out per service |
| 10 | S12, S13 | `labs/day-2/12-testing-pyramid/`, `13-static-analysis/` | **testing as a discipline** — the pyramid, `fmt`, TFLint, pre-commit |
| 11 | S14 · Security & policy scanners | `labs/day-2/14-security-scanners/` | policy + security scanning (planted insecure fixture — deliberately *not* the learner's project) |
| 12 | S16, S17 | `labs/day-2/16-tofu-test/`, `17-mocking/` | `tofu test` in depth — apply vs plan runs, and mocking beyond stage 9's first taste |
| 13 | S18 · Integration, e2e & cost | `labs/day-2/18-terratest-cost/` | integration + cost (optional tier) |
| 14 | S19 · Testing in CI/CD | `labs/day-2/19-testing-cicd/` | **CI** — the whole ladder as pipeline jobs |
| 15 | S20–S26 | `labs/day-3/**`, `examples/capstone/` | stacks → codegen → ordering → filtering → capstone |

**S10 and S11 carry no stage number** — the fit plan skips S10, and S11 is
hidden in the 3-day cut, so both sit outside the **Day-1** stage sequence.
Skippable does not mean unstaged elsewhere: S18 is hidden yet holds stage 13,
and S25 sits inside stage 15's span. S09 is delivered as stage 9b, the close of
Day 1; its `local_file.manifest` is the same project spine, not a new example.

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
`canonicalDayTotals()` in `scripts/deck-manifest.mjs` — are published here:

| Day | Slides | Labs | Slides+labs (planned) | Against the 390 budget |
| --- | ---: | ---: | ---: | --- |
| 1 | 637 | 345 | **982** | **+592 over** |
| 2 | 180 | 180 | 360 | 30 under |
| 3 | 200 | 200 | **400** | **+10 over** |

**Day 1 and Day 3 do not fit.** Say so when you plan the delivery: the honest
statement is "Day 1 is 592 over a one-day budget", not "Day 1 fits once you apply
the fit plan". These are **unrehearsed planning estimates** from section
frontmatter and lab headers — no rehearsal has timed them, so treat them as a
budget, not a stopwatch.

### Day 1 fit plan

This plan compresses **slide time only**. It starts at **727 minutes** of slide
time across all thirteen Day-1 sections (`dayOneSupersetSlidesTotal()`) and ends
at **497** (`dayOneFitTotal()`). Day-1 lab time — 345 minutes, S09's 60-minute
lab included — is untouched, so a fit-plan delivery still runs **842 minutes**
of slides+labs against a 390 budget. Be precise about what the plan now buys:
the compressed **deck alone** is 107 minutes over the whole-day budget, so the
plan does not make even the deck fit the day. What it does is remove 230
minutes of slide time and turn the remaining overflow into a planned, published
one instead of a mid-morning surprise.
Apply the rows in order. The first two remove optional/recommended material;
the remaining rows shorten core delivery while preserving each section's outcome.
S09 is **kept whole** (75 slide minutes, 60 lab minutes) — it is not a row here.
The compressed rows for S02, S03 and S04 keep the slides the fundamentals lanes
added (expressions; what plan compares against and `depends_on`; `import` and
`data`), so each still removes only its original 15 minutes.
The arithmetic is explicit: **727 → 692 → 637**, then
**637 → 622 → 597 → 582 → 567 → 552 → 537 → 522 → 507 → 497**.

| Order | Action | Minutes | Running total | Pedagogical cost |
| ---: | --- | ---: | ---: | --- |
| 1 | Skip S11 (optional); its `hide: true` toggle is already set | −35 | 692 | Defer the TACO vendor-selection landscape |
| 2 | Skip S10 (recommended) at its `DAY1-FIT` marker; keep `hide: false` | −55 | 637 | Defer the differentiator deep dive (incl. the import/adoption drill); S01's teaser and S05's encryption demo remain |
| 3 | Compress S00 from 40→25 at its marker | −15 | 622 | Move installation checks before class; retain orientation and first apply |
| 4 | Compress S01 from 55→30 at its marker | −25 | 597 | Make the detailed fork timeline pre-reading; retain why IaC, the design principles, the differentiators teaser, the alternatives, and governance |
| 5 | Compress S02 from 56→41 at its marker | −15 | 582 | Demo fewer block variants; retain syntax, references, the expressions slide, and the break→fix |
| 6 | Compress S03 from 68→53 at its marker | −15 | 567 | Use one lifecycle run; retain plan reading, what plan compares against, `depends_on`, and destroy |
| 7 | Compress S06 from 50→35 at its marker | −15 | 552 | Teach typed objects and validation; assign precedence variants as follow-up |
| 8 | Compress S15 from 50→35 at its marker | −15 | 537 | Teach one blocking condition plus `check`; assign the full assertion matrix |
| 9 | Compress S04 from 58→43 at its marker | −15 | 522 | Demonstrate state inspection live; retain `import` adoption and the `data` reference; assign backend migration as follow-up |
| 10 | Compress S05 from 60→45 at its marker | −15 | 507 | Demonstrate encryption; assign key rotation as follow-up |
| 11 | Compress S07 from 60→50 at its marker | −10 | **497** | Keep local module composition; demo registry/OCI lookup instead of running it |

`hide: true` remains reserved for optional sections, so S09, S10 and every core
section stay `hide: false`. Their comments in
[the three-day deck](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/slides-3day.md)
are delivery markers, not tier changes.

The fit plan's **497 is a different figure** from the day totals above: it is
Day-1 **slide** runtime only (`dayOneFitTotal()`), compressed from 727. Day-1
lab time (345) is untouched by it, so a fit-plan Day 1 still runs **842** of
slides+labs. Use 497 to check the deck against the day; use 982 to plan the day
itself. Note that 497 does not fit either: the compressed deck is 107 minutes
over the 390 budget before a single lab runs.

**Day 1 exceeds its budget by design.** Restoring S09 to the delivered cut
(operator decision) added 75 slide and 60 lab minutes, taking the planned day
from 790 to 925 and the fit-plan slide target from 400 to 475. The
fundamentals lanes then added 22 slide minutes (S02 +6 expressions, S03 +8 for
what plan compares against and `depends_on`, S04 +8 for `import` and `data`) and
35 lab minutes (Lab 02 +15, Lab 04 Step 8 +15, Lab 06 +5), taking the day to
**982** and the fit-plan slide target to **497**. That was chosen
over the budget on purpose: `count` is already used in the Day-1 labs
(`labs/day-1/00-setup/`, the naming module), and without S09 the delivered path
never taught it next to `for_each`. No fit-plan row claims the overflow away —
plan a long day, split Day 1 across two sessions, or trim further by the
cut order below. Rebalancing Day 1 is the open item under *Exploring* in the
[ROADMAP](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/ROADMAP.md#exploring-no-commitment-yet).

### Day 1 (author → guard → package)

**Standard delivery order** (delivered path after fit-plan skips):

`S00 → S01 → S02 → S03 → S06 → S15 → S04 → S05 → S07 → S08 → S09`

| Priority | Action | Source |
| --- | --- | --- |
| 1 | Skip **S11** (optional; already `hide: true`) | Fit plan row 1 (−35) |
| 2 | Skip **S10** at its `DAY1-FIT` marker | Fit plan row 2 (−55) |
| 3 | Compress S00–S03, S06, S15, S04, S05, S07 at markers until slide time is ≤497 | Fit plan rows 3–11 |
| Keep | **S08** at 65 min — flagship synthesis | `slides-3day.md` marker |
| Keep | **S09** at 75 min + 60 min lab — `count` vs `for_each`, `dynamic`, `lifecycle`, `moved`/`removed` | `slides-3day.md` marker |

Cut optional → recommended → compress core. Never drop S08 or S15's blocking
`precondition` + `check` beat when compressing. S09 stays `recommended`, so a
delivery that truly cannot run long may still cut it after S10 — but say so to
the room: it is the only place the delivered path teaches `count` vs `for_each`.

**The Day-1 resequencing was timing-neutral.** Moving S06 and S15 ahead of S04
and S05 changed no section's length, so it left the planning total and every
fit-plan row exactly as they were before the reorder — only the order changed.
What did move the total was S01 growing: 40→50 minutes to carry the
design-principles and alternatives beats, then 50→55 to carry the OpenTofu
differentiators teaser, plus Lab 04 growing 20→25 to add the drift step, and
then S09 returning to the delivered cut (+75 slides, +60 lab), then the
fundamentals lanes (+22 slides, +35 lab: expressions, `depends_on`, `import`).
Day 1 is now **982** planned, and the fit-plan slide target is **497**. The
Terraform→OpenTofu migration beat (two slides after the teaser) was absorbed
into S01's existing 55 planned minutes rather than growing them again — with
the fork timeline moved to pre-reading, the block carries it; watch the clock
there when delivering uncompressed.

**S09 is delivered: `count` vs `for_each` is taught on Day 1.** S09 closes the
day and restores four things to the delivered path: the `count` vs `for_each`
decision (index vs key addressing, and what a middle removal costs under each),
`dynamic` blocks, the `lifecycle` meta-arguments (`create_before_destroy`,
`prevent_destroy`, `ignore_changes`), and `moved`/`removed` refactoring without
replacement. The remaining accepted cost is S10: provider-level `for_each`,
`-exclude` and the hands-on `import`/adoption drill (Lab 10 Part B) stay off the
canonical cut. S01's differentiators teaser *names* provider `for_each` and
`-exclude` and points at S10 as follow-up, and S09's plan-time-width slide shows
`-exclude` as the workaround OpenTofu itself suggests — but naming is not
teaching, and the `import` drill is not run.

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
minutes, the figure the [Day 1 fit plan](#day-1-fit-plan) compresses —
explain time only.
**Lab** = `duration:` on the lab slide / lab header; add the two for the section's
share of the day. **3-day cut** = compress / skip from the fit plan or `hide:` in
`slides-3day.md`. All minutes are unrehearsed planning estimates.

### Day 1

| ID | Topic | Tier | Full (fit plan) | Lab | 3-day cut | Checkpoint (ask before moving on) | Watch-outs |
| --- | --- | --- | ---: | ---: | --- | --- | --- |
| S00 | Welcome & setup | core | 40 → **25** | 20 | Compress | Can everyone `tofu apply` local + reach LocalStack health? | First LocalStack boot; Docker not running |
| S01 | Infrastructure as Code | core | 55 → **30** | 20 | Compress | Declarative vs imperative — what does the plan give you that a script doesn’t? | Fork timeline is pre-reading when compressed; keep the six design principles, the differentiators teaser, the migration beat and the alternatives beat |
| S02 | HCL & building blocks | core | 56 → **41** | 35 | Compress | Name the six block types; which one alone mutates the world? What does `var.env == "prod" ? "ha" : "single"` return when `env = "dev"`? | Reference wiring; `.tofu` vs `.tf` aside |
| S03 | Core workflow | core | 68 → **53** | 20 | Compress | Read a plan line: `+` / `~` / `-` and “known after apply”? What does plan diff your config against — and when, if ever, do you need `depends_on`? | One lifecycle run when compressed |
| S06 | Variables & types | core | 50 → **35** | 30 | Compress | Break a validation on purpose — which phase fails? | Precedence variants follow-up when compressed |
| S15 | Preconditions & checks | core | 50 → **35** | 30 | Compress | Which guards fail at plan vs apply? What is `check` for? | Keep one blocking condition + `check` |
| S04 | State | core | 58 → **43** | 40 | Compress | Why is `terraform.tfstate` a secret store even when the CLI redacts? Then: a bucket exists that you must now own, and another team only needs its ARN — who writes `import {}`, and who writes `data`? | Backend migration is follow-up when compressed; Lab 04 Step 8 (adopt with `import {}`, reference with `data`, ~15 of the 40 lab minutes) needs LocalStack up (`task lab:up`) — `BucketAlreadyExists` on 8b's plain apply is the intended break, `Cannot import non-existent remote object` means LocalStack restarted and the bucket must be recreated; optional S3/LocalStack locking stretch (+~15 min) needs Docker + OpenTofu ≥1.10 |
| S05 | State encryption | core | 60 → **45** | 25 | Compress | Prove ciphertext on disk; what does `enforced = true` change? | PBKDF2 lab key handling; fallback migrate; optional +10 min KMS step (Lab 05 Step 6) |
| S07 | Modules | core | 60 → **50** | 35 | Compress | What is the module contract (inputs/outputs)? Demo registry/OCI only | No registry network on runnable path |
| S08 | Naming & labelling | core | **65** | 30 | Keep | Mock plan green, then LocalStack apply — validation enforces convention? | Step 4 needs LocalStack; panic-reset safe |
| S09 | Best practices | recommended | **75** | 60 | Keep | `count` vs `for_each` — which rebuilds on middle removal? And what does a `removed` block's plan tally say that a destroy's doesn't? | Closes Day 1 on an already-over-budget day; lab 09 authors a `dynamic` block and runs `moved`/`removed` refactors hands-on (archive provider, still no Docker) |
| S10 | Differentiators | recommended | 55 | 55 | **Skip** | (If run) Provider `for_each` / `-exclude` / `import` adoption — needs live LocalStack | Heavy emulator use |
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
| S19 | Testing in CI/CD | recommended | 30 | Keep | Why is `fmt` without `-check` a false green? | Paper + fixture; badge honesty; optional fork-and-run stretch is **+~15 min outside the 30-min budget** (GitHub account + network; offline skip = `task verify`) |

### Day 3 (shipped)

| ID | Section | Tier | Lab | 3-day cut | Checkpoint | Watch-outs |
| --- | --- | --- | ---: | --- | --- | --- |
| S20 | Why Terramate | core | 25 | Keep | Does Terramate manage state? (Answer: **no**.) | Disposable git root; empty `list` expected |
| S21 | Stacks | core | 30 | Keep | Why did a directory vanish from `terramate list`? | Silent skip without `stack {}` |
| S22 | Code generation | core | 30 | Keep | What restores a hand-edited `_backend.tf`? | `terramate generate`; detailed exit `2` |
| S23 | Orchestration | core | 30 | Keep | Why does plain `list` disagree with `--run-order`? | Cycle fail-closed; one `after` edge enough |
| S24 | Change detection | recommended | 25 | Keep / skip if short | Prove only the changed stack runs — what did network do? | Dirty `run --changed`; two-commit baseline; identity pin |
| S25 | Terramate CI + Cloud | optional | 25 | **Skip** (`hide`) unless time | Does the PR gate use `--changed`? Does Cloud manage state? (**no**) | Paper fixture; `fetch-depth: 0`; **no Cloud signup**; restore planted YAML |
| S26 | Capstone & wrap-up | core | 60 | Keep | Can the room green the unit lane and clean up with `lab:down`? Associate table = design check? | Drive `examples/capstone/` (no rewrite); short-passphrase break; panic-reset no residue; Terramate stretch optional; lab Part B build variant (author the 4th resource) is **stretch/homework, +40 min outside the 60-min budget** — reference `examples/capstone-build/` |
| S27 | Terragrunt vs Terramate | optional | 20 | **Skip** (`hide`) — appendix | (If run) Does `remote_state` host state? (Answer: **no** — it generates `backend.tf`.) | Read-only fixture, no Terragrunt install; ~40 min total incl. lab; restore planted claim (`git restore`) |
| S28 | Ecosystem tooling | optional | 20 | **Skip** (`hide`) — appendix | (If run) Does a fixing hook block the commit? (Answer: **fails the run and repairs the file** — the rerun is green.) | Needs `pre-commit` + one-time network hook fetch — else demo-only; `PCT_TFPATH` export; tenv/terraform-docs steps read-only; ~40 min total incl. lab |

---

## Facilitator checklist (each morning)

1. `task setup` — required tools green; Day-2/3 optionals as needed.
2. `task lab:up` once if any LocalStack lab is on today’s cut; confirm health URL.
3. Open `task dev:3day` presenter mode; skim today’s cut-order markers.
4. Know the panic-reset path cold before the first emulator lab.
5. End of day: `task lab:down` so tomorrow starts clean.
