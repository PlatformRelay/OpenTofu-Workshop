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
> `core`.

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
