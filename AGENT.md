# Contributor & agent guide

How this workshop is built. Read before authoring a section, a lab, or a module.

## Non-negotiable guardrails

1. **Vendor-neutral.** No employer, customer, or corporate names anywhere — slides,
   labs, code, assets, commits, docs. Product names (OpenTofu, Terraform, LocalStack,
   Spacelift, …) are fine when technically relevant.
2. **No tooling attribution.** Never name editors, generators, or AI assistants in
   commits, code, or docs. No `Co-Authored-By` trailers.
3. **Label AI imagery.** Every AI-generated image carries a visible `AI generated`
   footer (the `section-cover` layout does this automatically).
4. **OpenTofu-first.** Teach the `tofu` CLI. HCL's top-level block is still
   `terraform {}`, but prose, commands, and output say `tofu`. Note Terraform
   compatibility; don't run a parallel Terraform track.
5. **Stay current.** Track current OpenTofu behaviour and versions (see
   `agent-context/research-brief.md`). Verify version claims at authoring time.

## Repository map

- `slides.md` / `slides-3day.md` / `slides-templates.md` — root decks. Mostly
  frontmatter + `src:` import blocks. Toggle a section with `hide:` on its block.
- `pages/SNN-topic/index.md` — one self-contained section: a `section-cover`
  divider + content slides. **Never** reference another section's slide numbers,
  and **never** embed a lab body — reference labs by path.
- `labs/day-N/NN-topic.md` — standalone labs (see contract below).
- `modules/` + `examples/` — the runnable OpenTofu (see the module DoD below).
- `theme/` — the local Slidev theme: `layouts/`, `components/` (`IacIcon`,
  `KwCard`, `KwChip`, `CodeNote`, `CodeCallout`, `ArchBox`), `styles/theme.css`.
- `components/` — animated Vue teaching diagrams (`step` prop bound to `$clicks`).
- `agent-context/` — **gitignored** planning docs (roadmap, outline, stories,
  image prompts, ideas, operator board, research brief).
- `docs/decisions/` — tracked ADRs.

## Design system

Reuse the layouts; never invent a per-slide layout. Available: `cover`,
`section-cover`, `agenda`, `statement`, `code-walkthrough`, `code-annotated`,
`comparison`, `two-cols-code`, `topology`, `lab`, `recap`. Patterns:

- **`magic-move`** — grow an HCL manifest field-by-field, or morph HCL → plan → shell.
- **`CodeNote`** — click-synced side rail explaining highlighted lines
  (`{none|1-2|...}` line steps sync with `at="N"`).
- **`CodeCallout`** — floating overlay that labels a risky line in place.
- **`IacIcon`** — one badge per HCL construct (`kind="resource|module|state|test|…"`).
  Use a glyph where a slide names a **specific** construct; keep emoji for
  conceptual/decorative cards. Over-conversion is a defect.

## Lab authoring contract

Flat file `labs/day-N/NN-topic.md`, one per section. Every lab:

- Opens with a header table: **Section**, **Environment** (`localstack ✓ / mock ✓ /
  real-aws (optional)`), **Estimated time**.
- Has **Objective**, **Prerequisites**, **Files used**, numbered **Steps**,
  **Expected observations**, **Cleanup / panic reset**, optional **Stretch**.
- **Idiot-proof:** every task and question ships a `<details><summary>` spoiler with
  the exact command / expected output.
- **Break → fix:** show the failure, then the fix (e.g. enforced-plaintext error →
  add `fallback`).
- **Single source of truth:** the HCL a slide teaches **is** the file the lab
  applies. The next lab extends the same files.
- **Panic reset is always safe:** `task lab:down` + `tofu destroy` leaves no residue.

## Definition of Done (per section)

1. Slides authored in `pages/SNN-topic/index.md`, matching the outline beats.
2. Lab authored, idiot-proof with spoilers, break→fix.
3. Manifest single-source-of-truth: slide HCL ↔ lab HCL identical.
4. Components reused, not re-invented.
5. All three root decks build (`pnpm build`, `build:3day`, `build:templates`).
6. PDF/PNG export clean (magic-move + components render without overflow).
7. `task verify` green — `tofu fmt -check`, `validate`, and `tofu test` pass
   (plan/mock lane needs no cloud; integration lane uses LocalStack).
8. Cleanup safe; no guardrail violations.
9. Conventional Commit + gitmoji.

## Commits

`<emoji> <type>(<scope>): <subject>` — Conventional Commits + gitmoji. Types:
`feat` ✨ · `fix` 🐛 · `docs` 📝 · `refactor` ♻️ · `test` ✅ · `chore` 🔧 · `ci` 👷.
Scopes: `deck`, `labs`, `theme`, `modules`, `repo`, `ci`. Imperative, lowercase,
no trailing period.

## Build & verify

```bash
pnpm install
pnpm build && pnpm build:3day && pnpm build:templates   # decks
pnpm lint                                                # markdownlint (labs only)
task verify                                              # tofu fmt/validate/test
```
