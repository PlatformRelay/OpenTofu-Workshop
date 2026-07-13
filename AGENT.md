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

### Lab workdir & drift contract

A lab's runnable HCL lives as **tracked files in a sibling workdir**, not as
heredocs the learner pastes into `$HOME`. For a lab `labs/day-N/NN-topic.md`,
put its config under `labs/day-N/NN-topic/` (e.g. `labs/day-1/09-best-practices/main.tf`)
and reference those files **by path** from the prose. The heredoc-into-`$HOME`
pattern is never the primary flow — a learner should be able to
`task lab:validate DIR=labs/day-N/NN-topic` against real, `tofu fmt`-clean files.
The `lab:*` tasks all take `DIR=labs/day-N/NN-topic` (see `Taskfile.yaml`).

> **Carve-out:** `labs/fixtures/` is reserved for `scripts/verify.sh` drift
> self-test fixtures (e.g. `labs/fixtures/drift-demo/`). It is an intentional
> exception to the `labs/day-N/NN-topic` convention and is **not** a workshop
> section — never number it into the section namespace.

To make "slide↔lab single source of truth" **CI-verifiable**, tie a fenced
`hcl` block to its source file with an HTML-comment marker on the line
immediately above the fence (shown indented so the inner fences render):

    <!-- source: labs/fixtures/drift-demo/main.tf -->
    ```hcl
    terraform {
      required_version = ">= 1.8"
    }
    ```

`scripts/verify.sh` then diffs the block body against that file and **fails the
build, naming the file,** on any drift (or if the file is missing). Rules:

- **Annotated** block → diffed against its source; drift is a build failure.
- **Unannotated** `hcl` block → ignored (scratch/inline teaching HCL, or a
  partially-authored lab). A lab with only unannotated blocks **warns, never
  fails**, so in-flight work never blocks unrelated lanes.
- **Line endings must be LF.** Lab `.md` and `.tf` files are enforced to LF by
  the repo-root `.gitattributes`; the drift check also strips `\r` upstream so a
  stray CRLF cannot silently disarm detection. Only the block-body **comparison**
  additionally normalises a lone trailing newline — it is not a licence to author
  CRLF.
- The marker `<!-- source: … -->` and the ` ```hcl ` fence are expected at
  **column 0** (top level). A block written inside a list/indented context keeps
  its indentation in the body, so it will diff against the raw file only if the
  file is indented identically — author drift-checked blocks at top level.
- The block body must be **byte-identical** to the file. Generate the block
  *from* the file — never hand-sync the two. `labs/fixtures/drift-demo/` is the
  reference example.

## Definition of Done (per section)

1. Slides authored in `pages/SNN-topic/index.md`, matching the outline beats.
2. Lab authored, idiot-proof with spoilers, break→fix.
3. Manifest single-source-of-truth: slide HCL ↔ lab HCL identical.
4. Components reused, not re-invented.
5. All three root decks build (`pnpm build`, `build:3day`, `build:templates`).
6. PDF/PNG export clean (magic-move + components render without overflow).
7. `task verify` green — `tofu fmt -check`, `validate`, and `tofu test` pass
   (plan/mock lane needs no cloud; integration lane uses LocalStack).
8. **Presenter notes on every content slide** (see convention below) so anyone
   can deliver the deck, not just its author.
9. Cleanup safe; no guardrail violations.
10. Conventional Commit + gitmoji.

### Presenter-notes convention

Every **content** slide carries Slidev presenter notes so any facilitator can
deliver it. Slidev treats the **last HTML comment in a slide** as its presenter
notes: place it at the very end of the slide's markdown, after all content
(including any `::notes::` slot / `CodeNote` rail — that slot is a layout region,
**not** presenter notes) and immediately before the `---` separator. Notes show
in presenter mode and never render on the slide.

Each note contains three things: **what to say** (the beat's teaching point in
2–4 sentences), **a timing cue** (e.g. `~3 min`; on `lab` slides match the
`duration:` frontmatter), and **the transition line** into the next slide (on
`recap` slides echo the `next:` frontmatter). Anchor claims to what the slide
actually teaches — don't invent facts. Pure cover/divider slides with no
teaching content may be skipped; a divider with a spoken framing line is a beat
and gets a note.

```md
# Some slide title

- point one
- point two

<!--
Say: what this beat teaches, in 2-4 sentences. (~3 min)
Then: one transition line into the next slide.
-->
```

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
