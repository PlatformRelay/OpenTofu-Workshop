# 0011 — Toolchain lanes: Infracost optional, Terratest container-first

**Status:** Accepted

## Context

Two Part-2 tools threatened the workshop's **no-signup, local-first** guarantees (ADR
[0006](./0006-local-first-lab-environment.md)): Infracost requires a (free) API key, and
Terratest requires a Go toolchain a clean lab machine doesn't have. Decisions **D5 and D6
(2026-07-11)** scoped both.

## Decision

- **D5-A — Infracost is optional.** It appears as a **slide demo** plus a clearly-labelled
  **optional stretch** that states the free-API-key requirement up front. It is never a core
  lab step, so the workshop's no-signup promise holds.
- **D6-A — Terratest is container-first.** Terratest runs in a **pinned container** by default;
  no host Go toolchain is required to complete the workshop. An **optional host Go install**
  ships in the bootstrap as a separate story (US-0-GOTT) for learners who prefer native runs.

## Consequences

- A clean machine with the documented baseline toolchain can complete every core lab — no
  account sign-ups, no language toolchains beyond the pinned containers.
- S18 (Terratest + cost) is `optional` tier; its lab degrades gracefully when the learner skips
  the API key or has no Docker.
- Pinned container versions are bumped deliberately (reviewable diff), not by `latest` drift.
- If a future core section needs Infracost output, the section embeds captured output rather
  than making learners generate it live.
