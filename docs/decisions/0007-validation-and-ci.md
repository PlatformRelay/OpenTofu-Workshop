# 0007 — Validation & CI (the tested workshop)

**Status:** Accepted

## Context

Slide code that doesn't run, and labs that drift from the slides, are the usual rot
in a workshop. We want the **labs and modules themselves tested**, not just the
decks built.

## Decision

Three CI/`task verify` lanes:

- **Unit lane** (fast, no Docker): `tofu fmt -check -recursive`, `tofu validate`,
  and `tofu test` (`command = plan` + `mock_provider`) across every `modules/*`
  and `examples/*` with tests.
- **Integration lane** (LocalStack as a CI service): representative labs/examples
  run `tofu test` with `command = apply` against emulated AWS and assert real
  names/tags/resources.
- **Smoke lane**: check that HCL a slide teaches exists as the file a lab applies
  (slide ↔ lab single-source-of-truth guard).

Plus the deck lane: build `slides.md`, `slides-3day.md`, `slides-templates.md`, and
lint the labs (`markdownlint`, scoped to `labs/**` — Slidev multi-frontmatter
breaks linting the decks).

GitHub Actions: `ci.yml` (lint + build + verify), `pages.yml` (deploy the three
decks to Pages), `release.yml` (export PDFs on a `v*` tag). Two manual prereqs:
Pages source = GitHub Actions, and default branch = `main`.

## Consequences

- A section is not Done until `task verify` is green.
- Broken HCL or slide↔lab drift fails CI before merge.
- Learners can reproduce every check locally with `task verify`.
