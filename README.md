# OpenTofu Practitioner Workshop

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
> This workshop is under construction. The authored, usable path currently
> covers Day 1 sections **S00–S08 and S15**, with runnable labs **00–08 and 15**.
> Later sections remain visible as curriculum placeholders; do not treat their
> presence in a deck as completion.

### Prerequisites by workshop day

Run `task setup` before the workshop. It prints every detected version and
returns non-zero with install guidance and affected labs when something is
missing. It is safe to rerun and never installs without confirmation.

| Scope | Tools |
| --- | --- |
| Decks and Day 1 | OpenTofu ≥1.8, Node.js ≥20, pnpm, Task, Docker |
| Day 2 static analysis | TFLint |
| Day 2 security and policy | Trivy, Checkov, Conftest |
| Day 3 scale labs | Terramate |

`gum`, `awslocal`, and the AWS CLI improve the local experience but are
optional. Go is intentionally not installed by this bootstrap; the optional
Terratest lane documents its own container-first prerequisites.

## Choose your route

| I am a… | Start with | Then use |
| --- | --- | --- |
| Learner | [Canonical three-day workshop](slides-3day.md) — the standard delivery cut | [Lab 00](labs/day-1/00-setup.md) and the linked labs that follow |
| Facilitator | [Canonical three-day workshop](slides-3day.md) | The scope and timing warning below to plan cuts |
| Contributor | [Contributor guide](AGENT.md) | [Template gallery](slides-templates.md) for design patterns and the [decision index](docs/decisions/README.md) for architectural context |

## Deck choices

The repository uses a **superset + boil-down** model: one section library,
several deliberately different cuts.

| Deck | Purpose | Local fallback |
| --- | --- | --- |
| [Three-day cut](slides-3day.md) | Canonical learner and facilitator route; pre-boiled for standard delivery | `task dev:3day` |
| [Full superset](slides.md) | Every section S00–S26; use it to compose a custom delivery, not as the default learner route | `task dev` |
| [Template gallery](slides-templates.md) | Contributor-facing design-system and slide-pattern reference; not a workshop cut | `task dev:templates` |

Sections live in `pages/SNN-topic/index.md` and decks compose them with `src:`
imports. Contributors can set `hide: true` on an import to omit a section from a
cut.

## Scope and timing (known issue)

> [!WARNING]
> This repository is a **content superset**: the section library (`S00`–`S26`)
> is deliberately **larger than fits in three days**. At a **6.5 h/day** budget
> (~50/50 explain-then-run), the full superset runs well over three days, and
> even the **`core`** tier makes **Day 1 tight — it overflows a single day's
> budget**. That is a deliberate design choice ("choice over fit"), not an
> oversight. For a standard delivery, start with the canonical three-day cut;
> when trimming further, cut **`optional` first, then `recommended`**, and keep
> `core`. Before facilitating Day 1, apply the
> [executable Day 1 fit plan](#day-1-fit-plan).

### Day 1 fit plan

The planning estimate starts at **655 minutes** for every Day 1 section. Apply
the rows in order. The first three remove optional/recommended material; the
remaining rows shorten core delivery while preserving each section's outcome.
The arithmetic is explicit: **655 → 620 → 575 → 525**, then
**525 → 510 → 490 → 475 → 460 → 445 → 430 → 415 → 400 → 390**.

| Order | Action | Minutes | Running total | Pedagogical cost |
| ---: | --- | ---: | ---: | --- |
| 1 | Skip S11 (optional); its `hide: true` toggle is already set | −35 | 620 | Defer the TACO vendor-selection landscape |
| 2 | Skip S10 (recommended) at its `DAY1-FIT` marker; keep `hide: false` | −45 | 575 | Defer the differentiator survey; S05 still demonstrates encryption |
| 3 | Skip S09 (recommended) at its `DAY1-FIT` marker; keep `hide: false` | −50 | 525 | Defer lifecycle/refactoring patterns to follow-up study |
| 4 | Compress S00 from 40→25 at its marker | −15 | 510 | Move installation checks before class; retain orientation and first apply |
| 5 | Compress S01 from 40→20 at its marker | −20 | 490 | Make the detailed fork timeline pre-reading; retain why IaC and governance |
| 6 | Compress S02 from 50→35 at its marker | −15 | 475 | Demo fewer block variants; retain syntax, references, and the break→fix |
| 7 | Compress S03 from 60→45 at its marker | −15 | 460 | Use one lifecycle run; retain plan reading and destroy |
| 8 | Compress S04 from 50→35 at its marker | −15 | 445 | Demonstrate state inspection live; assign backend migration as follow-up |
| 9 | Compress S05 from 60→45 at its marker | −15 | 430 | Demonstrate encryption; assign key rotation as follow-up |
| 10 | Compress S06 from 50→35 at its marker | −15 | 415 | Teach typed objects and validation; assign precedence variants as follow-up |
| 11 | Compress S15 from 50→35 at its marker | −15 | 400 | Teach one blocking condition plus `check`; assign the full assertion matrix |
| 12 | Compress S07 from 60→50 at its marker | −10 | **390** | Keep local module composition; demo registry/OCI lookup instead of running it |

`hide: true` remains reserved for optional sections, so S09/S10 and every core
section stay `hide: false`. Their comments in
[the three-day deck](slides-3day.md) are delivery markers, not tier changes.

## Common local commands

```bash
task setup          # detect/install the workshop toolchain and deck dependencies
task dev:3day       # serve the canonical workshop at localhost:3030
task lab:up         # start LocalStack for labs that require it
task verify         # run fmt, validation, tofu tests, and documentation contracts
```

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
docs/decisions/       architectural decision records (ADRs)
setup/                bootstrap, lab runner, and environment guides
```

## Contributing

Read the [contributor guide](AGENT.md) for conventions, the lab authoring
contract, the Definition of Done, and guardrails. In short: OpenTofu-first
(`tofu`), vendor-neutral, Conventional Commits + gitmoji, and every lab task
carries a spoiler and a panic reset.

## Licence

Content and code are open source — see [LICENSE](LICENSE). “OpenTofu”,
“Terraform”, and other marks belong to their respective owners; see the
[artwork attribution](public/icons/README.md).
