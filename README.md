# OpenTofu Practitioner Workshop

An open-source, vendor-neutral, hands-on workshop for **Infrastructure as Code with
[OpenTofu](https://opentofu.org)** — write it, test it, scale it.

- **Part 1 — Foundations & best practices:** HCL, the core workflow, state,
  **client-side state encryption**, modules, and a tested **naming + labelling**
  module.
- **Part 2 — Infrastructure testing:** static analysis, security/policy scanners,
  validation & `check` blocks, native `tofu test`, `mock_provider`, integration
  testing, and CI.
- **Part 3 — Terramate:** stacks, code generation, orchestration, and change
  detection across a monorepo.

Roughly **50% hands-on**. Every lab runs locally on **[LocalStack](https://localstack.cloud)**
(an AWS emulator) plus `mock_provider` — **no cloud account, no bill**.

## Quick start

```bash
task setup          # detect & install tofu, docker, localstack, gum (interactive)
task dev            # serve the full deck (Slidev) at localhost:3030
task lab:up         # start LocalStack for the labs
task verify         # run the tested-workshop checks (fmt, validate, tofu test)
```

No `task`? The underlying commands are plain `pnpm` + `tofu` + `docker compose`;
see `Taskfile.yaml`.

## The decks

This repo uses a **superset + boil-down** model — one section library, several cuts:

| Deck | Command | What it is |
| --- | --- | --- |
| `slides.md` | `pnpm dev` | Superset — every section S00–S26, individually toggleable |
| `slides-3day.md` | `pnpm dev:3day` | Canonical 3-day delivery cut |
| `slides-templates.md` | `pnpm dev:templates` | Design-system & pattern gallery (start here) |

Sections live in `pages/SNN-topic/index.md` and are composed into a deck by `src:`
imports; set `hide: true` on an import to drop that section from a cut.

## Scope & timing (known issue)

This repo is a **content superset** — the section library (`S00`–`S26`) is deliberately
**larger than fits in three days**. At a **6.5 h/day** budget (~50/50 explain-then-run), the
full superset runs well over three days, and even the **`core`** tier makes **Day 1 tight — it
overflows a single day's budget**. That is a deliberate design choice ("choice over fit"), not
an oversight.

**Boil it down per delivery — you are not meant to teach every section:**

- **Tiers do the trimming.** Every section is `core`, `recommended`, or `optional`. Cut
  **`optional` first, then `recommended`**; keep `core`.
- **`slides-3day.md` is the canonical cut** — the pre-boiled 3-day subset. Start there for a
  standard delivery; reach for `slides.md` (the full superset) only to choose which sections to
  include.

## Layout

```
slides*.md            root decks (superset / 3-day / templates)
pages/SNN-topic/      one self-contained section per folder
labs/day-N/           standalone, idiot-proof labs (LocalStack + mock)
modules/              naming/ + labels/ — the flagship tested modules
examples/             runnable roots wiring modules (LocalStack)
theme/                local Slidev theme (layouts, components, IacIcon)
components/           animated Vue teaching diagrams
public/icons/         OpenTofu marks + HCL block glyphs
docs/decisions/       architectural decision records (ADRs)
setup/                gum-based bootstrap & lab runner
```

## Contributing

Read [`AGENT.md`](./AGENT.md) for conventions, the lab authoring contract, the
Definition of Done, and guardrails. In short: OpenTofu-first (`tofu`),
vendor-neutral, Conventional Commits + gitmoji, and every lab task carries a
spoiler and a panic reset.

## Licence

Content and code are open source — see [`LICENSE`](./LICENSE). "OpenTofu" and
"Terraform" and other marks belong to their respective owners; see
[`public/icons/README.md`](./public/icons/README.md) for artwork attribution.
