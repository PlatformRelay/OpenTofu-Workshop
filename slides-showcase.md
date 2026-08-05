---
theme: ./theme
title: OpenTofu Practitioner Workshop
info: |
  Showcase root deck — NOT a delivery cut. A tiny page-range composition over
  the real section library, used only to render the README's animated
  deck-showcase GIF (`pnpm showcase:gif` → scripts/make-showcase-gif.mjs).
  Page ranges reference slide numbers inside each section's index.md; if a
  section is restructured, update the range here. The pipeline asserts one
  rendered slide per `src:` import (slidev silently drops a dead range), so a
  stale range fails the run — and CI re-renders the GIF on every push/PR.
src: ./pages/S00-welcome/index.md#1
---

---
# S03 · Core workflow — plan/apply loop animation
src: ./pages/S03-core-workflow/index.md#5
---

---
# S04 · State — desired → state → actual reconcile animation
src: ./pages/S04-state/index.md#2
---

---
# S05 · State encryption — client-side encryption pipeline animation
src: ./pages/S05-state-encryption/index.md#4
---

---
# S17 · Mocking — mock_provider swap animation
src: ./pages/S17-mocking/index.md#3
---

---
# S21 · Stacks — Terramate discover-phase animation
src: ./pages/S21-stacks/index.md#3
---
