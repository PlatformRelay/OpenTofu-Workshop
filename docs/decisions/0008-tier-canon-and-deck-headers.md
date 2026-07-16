# 0008 — Section tier canon & deck-header convention

**Status:** Accepted

## Context

The workshop ships as a **superset deck** (`slides.md`, all sections) and a **3-day cut**
(`slides-3day.md`, the subset actually delivered). Section selection has to be an *informed,
enforced* choice, not tribal knowledge:

- Every section needs a **tier** that says how essential it is, and the two decks must agree on
  that tier for every shared section.
- The 3-day cut hides sections by toggling `hide:` on their `src:` import block; "what is hidden"
  must be derivable from tier, not maintained by hand in two places.
- A reader scanning `slides.md` should see each section's identity (number, title, tier, day)
  without opening the section file.

Decision **D1 — tier canon (A)** (2026-07-11) fixed the canon; this ADR records it and the
header convention that makes it visible and machine-checkable.

## Decision

**1. Three tiers, one canonical meaning.**

| Tier | Meaning | In the 3-day cut |
| --- | --- | --- |
| `core` | Essential; the workshop doesn't make sense without it. | Always shown. |
| `recommended` | Valuable; included when time allows. | Shown unless time forces a cut. |
| `optional` | Enrichment / stretch. | **Hidden** (`hide: true`). |

The invariant is **`hidden ⟺ optional`**: a section is hidden in `slides-3day.md` **iff** its tier
is `optional`. Per D1-A, S05 and S14 are `core` everywhere; S11, S18, S25 are `optional` (hence
the 3-day hide-list).

**2. Tier lives in two agreeing places, and only those.**

- **Section frontmatter** — `pages/SNN-topic/index.md` carries `section: 'NN'`, `day: Day N`,
  `tier: <core|recommended|optional>`.
- **Deck heading comment** — in `slides.md` (and `slides-3day.md`) each `src:` import is preceded
  by `# SNN · Title · tier · Day` (e.g. `# S04 · State · core · Day 1`).

**3. The convention is enforced, not documented-and-hoped.** `scripts/verify.sh` (US-F-TIERS)
fails the build when: (a) a section's tier differs between `slides.md` and `slides-3day.md`, or
(b) the hide-invariant is violated (`hide:true ⟺ optional`). The `verify-selftest.sh` fail-path
cases cover both (cross-deck tier mismatch on S05; hide-invariant violation on S18).

## Consequences

- Section selection for a delivery is a **tier filter**, reproducible and reviewable in a diff.
- The two decks cannot silently disagree on a tier, and "hidden" can't drift from "optional" —
  the gate catches it.
- A new section MUST set `tier`/`day`/`section` frontmatter **and** the `# SNN · … · tier · Day`
  heading comment, or the tier gate fails. (The convention lives in `AGENT.md` under
  "Section headers & tiers".)
- Re-tiering a section (e.g. the S15 re-sequence, [0012](./0012-s15-into-day-1.md)) is a one-line
  change in each deck heading + frontmatter, guarded by the gate — no hand-audit of the hide-list.
