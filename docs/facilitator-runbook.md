# Facilitator runbook

Practical delivery notes for the **canonical three-day cut**
([`slides-3day.md`](../slides-3day.md)). Pair with presenter notes on each
slide and the [scope and timing](../README.md#scope-and-timing-known-issue)
warning in the README.

**Shipped** = authored slides + lab (not a stub). All canonical sections
through **S26** are shipped; optional sections stay skippable via cut-order /
`hide:`.

| Day | Serve | Preflight |
| --- | --- | --- |
| Any | `task setup` then `task dev:3day` | `tofu version` ≥1.8; Docker (or k8s path) for LocalStack labs |
| 1–2 LocalStack labs | `task lab:up` before the first `localstack ✓` step | Health: <http://localhost:4566/_localstack/health> |
| 2 scanners | TFLint, Trivy, Checkov, Conftest on `PATH` | `task setup` optional Day-2 tools |
| 3 Terramate | Terramate on `PATH` (spoilers pinned ~0.17.x) | No Docker required for S20–S25 path |

---

## Live cut-order

Budget is **6.5 h/day** (~50/50 explain-then-run). Full section minutes for Day 1
come from the [Day 1 fit plan](../README.md#day-1-fit-plan). Lab minutes come from
section frontmatter / lab headers. Day 2–3 full-section budgets are not published
in-repo yet — use **lab duration + presenter-note cues**; do not invent totals.

### Day 1 (author → guard → package)

**Standard delivery order** (core path after fit-plan skips):

`S00 → S01 → S02 → S03 → S04 → S05 → S06 → S15 → S07 → S08`

| Priority | Action | Source |
| --- | --- | --- |
| 1 | Skip **S11** (optional; already `hide: true`) | README fit plan row 1 (−35) |
| 2 | Skip **S10**, then **S09** at their `DAY1-FIT` markers | README rows 2–3 (−45, −50) |
| 3 | Compress S00–S07 / S15 at markers until ≤390 min | README rows 4–12 |
| Keep | **S08** at 65 min — flagship synthesis | `slides-3day.md` marker |

Cut optional → recommended → compress core. Never drop S08 or S15's blocking
`precondition` + `check` beat when compressing.

### Day 2 (test)

Canonical visible order: `S12 → S13 → S14 → S16 → S17 → S19`.

| Priority | Action |
| --- | --- |
| Skip first | **S18** (optional; already `hide: true`) — Terratest/Infracost tip |
| If short | Shorten explain on S12; keep S13→S14→S16 chain intact |
| Keep | S17 mock path (Docker-down proof) and S19 `fmt -check` false-green |

### Day 3 (scale)

Canonical visible order: `S20 → S21 → S22 → S23 → S24 → S26` (+ optional S25).

| Priority | Action |
| --- | --- |
| Ship | S20 → S21 → S22 (generate) → S23 (order) → S24 (`--changed` / `--tags`) → **S26** capstone |
| If short | Skip **S24** (recommended) — deepen S23 Q&A; keep core S20–S23; **keep S26** wrap if at all possible |
| Optional | **S25** (`hide: true` in 3-day cut) — `--changed` CI + Cloud overview; skip unless time |
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
[`setup/localstack.md`](../setup/localstack.md).

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

Timing legend: **Section** = README Day 1 fit-plan full budget (explain+lab).
**Lab** = `duration:` on the lab slide / lab header. **3-day cut** = compress /
skip from the fit plan or `hide:` in `slides-3day.md`.

### Day 1

| ID | Topic | Tier | Full (fit plan) | Lab | 3-day cut | Checkpoint (ask before moving on) | Watch-outs |
| --- | --- | --- | ---: | ---: | --- | --- | --- |
| S00 | Welcome & setup | core | 40 → **25** | 20 | Compress | Can everyone `tofu apply` local + reach LocalStack health? | First LocalStack boot; Docker not running |
| S01 | Infrastructure as Code | core | 40 → **20** | 20 | Compress | Declarative vs imperative — what does the plan give you that a script doesn’t? | Fork timeline is pre-reading when compressed |
| S02 | HCL & building blocks | core | 50 → **35** | 20 | Compress | Name the seven block types; which one alone mutates the world? | Reference wiring; `.tofu` vs `.tf` aside |
| S03 | Core workflow | core | 60 → **45** | 20 | Compress | Read a plan line: `+` / `~` / `-` and “known after apply”? | One lifecycle run when compressed |
| S04 | State | core | 50 → **35** | 20 | Compress | Why is `terraform.tfstate` a secret store even when the CLI redacts? | Backend migration is follow-up when compressed |
| S05 | State encryption | recommended\* | 60 → **45** | 25 | Compress | Prove ciphertext on disk; what does `enforced = true` change? | PBKDF2 lab key handling; fallback migrate |
| S06 | Variables & types | core | 50 → **35** | 25 | Compress | Break a validation on purpose — which phase fails? | Precedence variants follow-up when compressed |
| S15 | Preconditions & checks | core | 50 → **35** | 30 | Compress | Which guards fail at plan vs apply? What is `check` for? | Keep one blocking condition + `check` |
| S07 | Modules | core | 60 → **50** | 35 | Compress | What is the module contract (inputs/outputs)? Demo registry/OCI only | No registry network on runnable path |
| S08 | Naming & labelling | core | **65** | 30 | Keep | Mock plan green, then LocalStack apply — validation enforces convention? | Step 4 needs LocalStack; panic-reset safe |
| S09 | Best practices | recommended | 50 | 30 | **Skip** | (If run) `count` vs `for_each` — which rebuilds on middle removal? | Only if time returns |
| S10 | Differentiators | recommended | 45 | 25 | **Skip** | (If run) Provider `for_each` / `-exclude` — needs live LocalStack | Heavy emulator use |
| S11 | TACO landscape | optional | 35 | 20 | **Skip** (`hide`) | (If run) Constraints-first platform pick — paper only | No tooling |

\*S05 is `recommended` in section frontmatter; Day 1 fit plan still budgets it
as a compressible core delivery beat.

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

---

## Facilitator checklist (each morning)

1. `task setup` — required tools green; Day-2/3 optionals as needed.
2. `task lab:up` once if any LocalStack lab is on today’s cut; confirm health URL.
3. Open `task dev:3day` presenter mode; skim today’s cut-order markers.
4. Know the panic-reset path cold before the first emulator lab.
5. End of day: `task lab:down` so tomorrow starts clean.
