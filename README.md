# OpenTofu Practitioner Workshop

[![CI](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/ci.yml/badge.svg)](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/ci.yml)
[![Pages](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/pages.yml/badge.svg)](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/pages.yml)
[![Documentation](https://img.shields.io/badge/documentation-GitHub%20Pages-2ea44f?logo=readthedocs&logoColor=white)](https://platformrelay.github.io/OpenTofu-Workshop/)
[![Release](https://img.shields.io/github/v/release/PlatformRelay/OpenTofu-Workshop)](https://github.com/PlatformRelay/OpenTofu-Workshop/releases)
[![License: 0BSD](https://img.shields.io/github/license/PlatformRelay/OpenTofu-Workshop)](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/LICENSE)

An open-source, vendor-neutral, hands-on workshop for **Infrastructure as Code
with [OpenTofu](https://opentofu.org)**. The learning journey follows the way
infrastructure grows in practice:

1. **Author** — learn HCL, the plan/apply workflow, state, encryption,
   validation, modules, naming, and labelling.
2. **Test** — add static checks, policy and security scanners, `check` blocks,
   native `tofu test`, mocks, integration tests, and CI.
3. **Scale** — use Terramate stacks, generation, orchestration, and change
   detection across a monorepo.

Roughly **50% is hands-on**.

**Preview it now:** docs and decks are live on GitHub Pages.

- **Documentation home:** <https://platformrelay.github.io/OpenTofu-Workshop/>
- **Live deck (full superset):** <https://platformrelay.github.io/OpenTofu-Workshop/deck/>
- **Live deck (canonical 3-day cut):** <https://platformrelay.github.io/OpenTofu-Workshop/deck/3day/>
- **Template gallery:** <https://platformrelay.github.io/OpenTofu-Workshop/deck/templates/>

Legacy `/3day/` and `/templates/` URLs redirect into `/deck/…`.

![Animated tour of the workshop deck — real slides stepping through their click animations](docs/images/deck-showcase.gif)

<sub>Real deck, no hand-taken screenshots: CI re-renders this tour from the slide sources
(`pnpm showcase:gif`).</sub>

> [!IMPORTANT]
> Labs use `mock_provider` or [LocalStack](https://localstack.cloud), an AWS
> emulator running on your machine. You need **no cloud account and incur no
> cloud bill**.

## Start here

For the standard learner route:

1. Open the [canonical three-day workshop](slides-3day.md). If a published deck
   is unavailable, serve it locally with `task dev:3day`.
2. Complete [Lab 00: setup and first resource](labs/day-1/00-setup.md), starting
   with `task setup` and then `task lab:up` when the lab asks for LocalStack.
3. If the emulator does not become healthy, use the
   [LocalStack setup and troubleshooting guide](setup/localstack.md).

> [!NOTE]
> All three days are authored: sections **S00–S28** and their labs, plus the
> capstone, are shipped (not stubs). Optional sections stay skippable via the
> cut-order / `hide:` toggles. The section library is a deliberate **superset**
> that runs longer than three days — read
> [Scope and timing](#scope-and-timing-known-issue) and apply the runbook's
> [Day 1 fit plan](docs/facilitator-runbook.md#day-1-fit-plan) before
> facilitating.

### Prerequisites by workshop day

Run `task setup` before the workshop. It prints every detected version and
returns non-zero with install guidance and affected labs when something is
missing. It is safe to rerun and never installs without confirmation.

| Scope | Tools |
| --- | --- |
| Decks and Day 1 | OpenTofu ≥1.9, Node.js ≥20, pnpm, Task, Docker |
| Day 2 static analysis | TFLint |
| Day 2 security and policy | Trivy, Checkov, Conftest |
| Day 3 scale labs | Terramate |
| Optional Terratest (S18) | Docker (container lane) — or host Go ≥1.22 |

`gum`, `awslocal`, and the AWS CLI improve the local experience but are
optional. Go is **not** installed by default. Terratest is **container-first**
([ADR 0011](docs/decisions/0011-toolchain-lanes.md)):

```bash
task lab:terratest DIR=labs/fixtures/terratest-smoke   # pinned Go+tofu container vs LocalStack
# Host-Go alternative (optional):
BOOTSTRAP_WITH_GO=1 bash setup/bootstrap.sh            # or: bash setup/bootstrap.sh --with-go
task lab:up && task lab:terratest:host DIR=labs/fixtures/terratest-smoke
```

No Docker? The container lane fails fast and points at the host-Go commands
above.

## Choose your route

| I am a… | Start with | Then use |
| --- | --- | --- |
| Learner | [Docs home](https://platformrelay.github.io/OpenTofu-Workshop/) or [canonical three-day deck](https://platformrelay.github.io/OpenTofu-Workshop/deck/3day/) — offline: [slides-3day.md](slides-3day.md) / `task dev:3day` | [Lab 00](labs/day-1/00-setup.md) and the [labs index](https://platformrelay.github.io/OpenTofu-Workshop/labs/) |
| Facilitator | [Facilitator runbook](https://platformrelay.github.io/OpenTofu-Workshop/facilitator-runbook/) (clone: [docs/facilitator-runbook.md](docs/facilitator-runbook.md)) | [3-day deck](https://platformrelay.github.io/OpenTofu-Workshop/deck/3day/), the scope and timing warning below, and [Associate alignment](https://platformrelay.github.io/OpenTofu-Workshop/associate-alignment/) (design check, not exam prep) |
| Contributor | [Contributor guide](docs/authoring-guide.md) | [Template gallery](slides-templates.md) / `task dev:templates` and the [decision index](docs/decisions/README.md) |

## Run this workshop for your team

This is not only a deck to read — it is a delivery kit built so that someone
who is not the author can teach it in-house.

- **What you get:** a slide library with a pre-boiled three-day cut, a
  standalone lab per section (LocalStack or `mock_provider` — no cloud
  account, no bill), a [facilitator runbook](docs/facilitator-runbook.md)
  with delivery order, timing arithmetic, per-section checkpoints, and a
  panic-reset drill, plus a [syllabus](docs/syllabus.md) mapping every
  section to its lab.
- **How to deliver it:** clone, run `task setup`, rehearse with
  `task dev:3day`, then follow the
  [runbook](docs/facilitator-runbook.md) — including its
  [Day 1 fit plan](docs/facilitator-runbook.md#day-1-fit-plan) — for the
  standard three-day delivery.
- **Fork and customize:** the library is a superset with several cuts — flip
  `hide:` toggles, compose your own deck (`pnpm deck -- --range S05-S09`),
  restyle the local Slidev theme, and redistribute freely: the
  [0BSD licence](LICENSE) requires no attribution, so your fork can be fully
  yours.

Found a rough edge while delivering it? See [Contributing](#contributing) —
small fixes take the fast path.

## Deck choices

The repository uses a **superset + boil-down** model: one section library,
several deliberately different cuts.

| Deck | Purpose | Local fallback |
| --- | --- | --- |
| [Three-day cut](slides-3day.md) | Canonical learner and facilitator route; pre-boiled for standard delivery | `task dev:3day` |
| [Full superset](slides.md) | Every section S00–S28; use it to compose a custom delivery, not as the default learner route | `task dev` |
| [Template gallery](slides-templates.md) | Contributor-facing design-system and slide-pattern reference; not a workshop cut | `task dev:templates` |

Sections live in `pages/SNN-topic/index.md` and decks compose them with `src:`
imports. Contributors can set `hide: true` on an import to omit a section from a
cut.

## Scope and timing (known issue)

> [!WARNING]
> This repository is a **content superset**: the section library (`S00`–`S28`)
> is deliberately **larger than fits in three days**, and even the canonical
> three-day cut overflows on two of the three days against a **390 min/day**
> budget (6.5 h, ~50/50 explain-then-run). That is a deliberate design choice
> ("choice over fit"), not an oversight. The planning arithmetic lives in the
> facilitator runbook: the published
> [day totals](docs/facilitator-runbook.md#live-cut-order) and the executable
> [Day 1 fit plan](docs/facilitator-runbook.md#day-1-fit-plan), which
> compresses Day-1 **slide** time from 705 minutes to 400 and leaves the labs
> untouched. Apply the fit plan before facilitating; when trimming further,
> cut **`optional` first, then `recommended`**, and keep `core`. All totals
> are unrehearsed planning estimates, never measured timings.

## Common local commands

```bash
task setup          # detect/install the workshop toolchain and deck dependencies
task dev:3day       # serve the canonical workshop at localhost:3030
task lab:up         # start LocalStack for labs that require it
task lab:terratest  # optional: run Go tests in the pinned Terratest container
task verify         # run fmt, validation, tofu tests, and documentation contracts
task pages:build    # MkDocs + hash-routed decks → ./site (needs MkDocs)
task pages:preview  # serve ./site at http://localhost:4173
```

`task verify` / `scripts/verify.sh` need **Bash ≥4** (`shopt globstar`). macOS
`/bin/bash` is still 3.2 and fails if it wins on `PATH`; Homebrew bash 5 (or
CI's Ubuntu bash) is fine — put `/opt/homebrew/bin` or `/usr/local/bin` first.

No `task`? The underlying commands are plain `pnpm`, `tofu`, and Docker Compose;
see [Taskfile.yaml](Taskfile.yaml) for their exact definitions.

## Repository layout

```text
slides*.md            root decks (superset / 3-day / templates)
pages/SNN-topic/      one self-contained section per folder
labs/day-N/           standalone labs (LocalStack + mock)
modules/              naming/ + labels/ — the flagship tested modules
examples/             runnable roots wiring modules (LocalStack)
theme/                local Slidev theme (layouts, components, IacIcon)
components/           animated Vue teaching diagrams
public/icons/         OpenTofu marks + HCL block glyphs
mkdocs.yml            GitHub Pages docs site (Material)
docs/                 published MkDocs pages + ADRs under docs/decisions/
docs/facilitator-runbook.md  facilitator delivery guide
docs/associate-alignment.md  Associate coverage map (design check, not exam prep)
scripts/pages-build.sh       MkDocs + Slidev /deck/ Pages tree
setup/                bootstrap, lab runner, and environment guides
```

## Contributing

Curious where the workshop is heading? The [roadmap](ROADMAP.md) lists the
near-term themes and the standing community asks.

Fixing a typo, a broken link, or a wrong command? **Just open a PR** —
[CONTRIBUTING.md](CONTRIBUTING.md) starts with a small-fix fast path: no
required reading, no commit-message conventions, no local toolchain;
maintainers squash-merge and format the message. For substantive changes
(slides, labs, modules, scripts), read [CONTRIBUTING.md](CONTRIBUTING.md) and
the [contributor guide](docs/authoring-guide.md) for conventions, the lab authoring
contract, the Definition of Done, and guardrails. In short: OpenTofu-first
(`tofu`), vendor-neutral, Conventional Commits + gitmoji, and every lab task
carries a spoiler and a panic reset.

## Licence

**[0BSD](LICENSE)** — use, copy, modify, redistribute, and sell freely. No
attribution required. Copyright (C) 2026 Platform Relay.

“OpenTofu”, “Terraform”, and other marks belong to their respective owners; see
the [artwork attribution](public/icons/README.md).
