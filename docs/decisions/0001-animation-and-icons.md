# 0001 — Animation & icon technology

**Status:** Accepted

## Context

The deck teaches HCL and IaC state changes. We need (a) code that visibly grows or
morphs, (b) state/flow diagrams that move on click, and (c) a consistent icon set —
all of which must survive **static build and PDF/PNG export** (the release
artifact), not just the live server.

## Decision

- **Code changes** use Slidev **`magic-move`** (Shiki) — grow a manifest field by
  field, or morph HCL → plan → shell.
- **State / flow diagrams** use **pure Vue + CSS transitions** driven by a `step`
  prop bound to `$clicks` (a `<TransitionGroup>` with `enter/leave/move` classes).
  We avoid motion libraries that mishandle leave animations under export.
- **Icons** are static `<img>` SVGs loaded from `public/` (no build-time icon
  plugin), via `theme/components/IacIcon.vue`. `kind="…"` selects an HCL-block
  glyph; `name="…"` selects a brand/tool mark.

## Consequences

- Everything renders identically live and in export.
- Animated diagrams are ~30 lines of CSS each; authors reuse components, never
  re-implement per slide.
- New icons require an SVG plus a one-line union entry in `IacIcon.vue`.
