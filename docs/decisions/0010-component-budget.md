# 0010 — Animated-component budget: fund three, defer four

**Status:** Accepted

## Context

The outline referenced seven animated Vue teaching diagrams, but none existed — the outline was
a promise no component backed. Building all seven up-front would delay content authoring by
weeks; building none leaves every referencing section without its headline visual. Decision
**D3 (2026-07-11)** set an explicit budget.

## Decision

- **Fund three now:** `PlanApplyFlow` (S03), `StateEncryptionFlow` (S05), `TestPyramid`
  (S12/S18) — the components whose sections sit earliest on the critical path.
- **Defer four as P3 stories:** `DependencyGraph`, `StateReconcile`, `MockProviderFlow`,
  `TerramateOrchestration` — built when their sections are authored and the value is proven,
  not speculatively.
- **Sections never block on a component.** Every section that wants a diagram names its
  **magic-move fallback** so authoring proceeds with or without the component.
- Component contract (see `AGENT.md`): a `step` prop bound to `$clicks`, out-of-range values
  **clamped** — a component never throws or blanks a slide.

## Consequences

- Content lanes and component lanes parallelize; a missing diagram degrades to a magic-move,
  never to a blocked section.
- Deferred components are re-scored when their sections land — `DependencyGraph` was built
  exactly this way (2026-07-15, after S02 and S07 were authored made it well-timed).
- All components live in `components/`, auto-imported into every deck; new ones enter only
  through a funded story, keeping the deck's animation surface deliberate.
