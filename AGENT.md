# Contributor & agent guide

Thin entry point. The authoring contract itself lives in the tracked, human-facing
**[authoring guide](docs/authoring-guide.md)** — read that before authoring a
section, a lab, or a module. This file only routes you there and carries a few
agent-operational notes.

## Where things live

| Topic (former `AGENT.md` section) | Now at |
| --- | --- |
| Non-negotiable guardrails | [authoring guide · guardrails](docs/authoring-guide.md#non-negotiable-guardrails) |
| Published site (GitHub Pages) | [authoring guide · published site](docs/authoring-guide.md#published-site-github-pages) |
| Repository map + `US-*` gate-name legend | [authoring guide · repository map](docs/authoring-guide.md#repository-map) |
| Design system (layouts, components, patterns) | [authoring guide · design system](docs/authoring-guide.md#design-system) |
| Section headers & tiers | [authoring guide · section headers & tiers](docs/authoring-guide.md#section-headers--tiers) |
| Lab authoring contract + evolving project | [authoring guide · lab authoring contract](docs/authoring-guide.md#lab-authoring-contract) |
| Lab workdir & drift contract (byte-fenced `<!-- source: … -->` blocks) | [authoring guide · lab workdir & drift contract](docs/authoring-guide.md#lab-workdir--drift-contract) |
| Definition of Done + presenter-notes convention | [authoring guide · definition of done](docs/authoring-guide.md#definition-of-done-per-section) |
| Commit convention | [authoring guide · commits](docs/authoring-guide.md#commits) |
| Build & verify | [authoring guide · build & verify](docs/authoring-guide.md#build--verify) |

Contribution workflow (issues, PRs, small-fix fast path): [CONTRIBUTING](CONTRIBUTING.md).
Delivery: [facilitator runbook](docs/facilitator-runbook.md). Decisions:
[ADR index](docs/decisions/README.md). Older references of the form
"`AGENT.md` · *section*" resolve via the table above.

## Agent-operational notes

- **Guardrails are non-negotiable** — vendor-neutral content, no tooling/AI
  attribution or `Co-Authored-By` trailers, visible `AI generated` footer on AI
  imagery, `tofu`-first prose. Full text in the guide.
- **Commits:** `<gitmoji> <type>(<scope>): <subject>` (Conventional Commits +
  gitmoji; see the guide's commit section for types and scopes).
- **Gates before handing work back** (all must be green, see the guide's
  build & verify section for context):

  ```bash
  pnpm install
  task verify                    # tofu fmt/validate/test + drift + repo contracts
  pnpm lint                      # markdownlint (labs only)
  pnpm decks:check && pnpm test:deck
  node scripts/lab-contract.mjs && node scripts/lab-inventory.mjs --check
  pnpm link-check                # offline link/anchor check (README, docs, labs)
  ```

- `task verify` / `scripts/verify.sh` need **Bash ≥ 4**; the fmt gate scans
  **git-tracked** `*.tf` only — stage new files before trusting a green run.
