# 0003 — Deck composition: superset & boil-down

**Status:** Accepted

## Context

The same content is delivered as a full reference and as a time-boxed 3-day course,
and we maintain a design-system gallery. Duplicating slides across decks rots.

## Decision

A **superset + boil-down** model. One section library under `pages/`; each root
deck is mostly frontmatter plus `src:` import blocks:

- `slides.md` — superset, every section visible.
- `slides-3day.md` — same imports, optional-tier (and selected deep-dive) sections
  set `hide: true`.
- `slides-templates.md` — the design-system & pattern gallery (self-contained).

A cut is defined purely by which imports are hidden — no content is copied.

## Consequences

- Editing a section updates every cut at once.
- New cuts are a new root deck listing the same imports with different `hide:` flags.
- Sections must stay self-contained (see 0002) for atomic toggling to work.
