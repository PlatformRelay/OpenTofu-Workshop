# 0002 — Repository & content structure

**Status:** Accepted

## Context

The workshop is large (~27 sections across three parts) and delivered in multiple
cuts. Content, labs, runnable code, and planning material must stay navigable and
each live in exactly one place.

## Decision

- **One section per folder:** `pages/SNN-topic/index.md`, self-contained (a
  `section-cover` divider + content). Sections never reference each other's slide
  numbers and never embed lab bodies.
- **Labs are standalone:** flat `labs/day-N/NN-topic.md`, one per section,
  referenced by path — never inlined into slides.
- **Runnable OpenTofu lives in `modules/` and `examples/`**, not in slide fences;
  slides quote it, labs apply it (single source of truth).
- **Planning material is gitignored** under `agent-context/`; only tracked
  decisions live in `docs/decisions/`.

## Consequences

- A section can be authored, reviewed, and toggled independently.
- Slide ↔ lab drift is a checkable invariant (`task verify` smoke lane).
- The repo mirrors a sibling Kubernetes workshop's conventions, so contributors
  moving between them find the same shape.
