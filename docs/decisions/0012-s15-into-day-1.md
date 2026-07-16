# 0012 — S15 (validation & checks) re-sequenced into Day 1

**Status:** Accepted

## Context

S15 (validation recap, `precondition`/`postcondition`, non-blocking `check` blocks) originally
sat in Day 2's testing arc. Prior workshop deliveries taught a hard lesson: **guardrails belong
with the basics** — teaching health/validation late means learners write a full day of
unguarded configuration first. Decision **D8 (2026-07-11, option B)** applied that lesson here;
US-X-ESSENTIALS landed it (2026-07-14).

## Decision

- S15's import block moves **between S06 and S07** in both root decks; its frontmatter reads
  `day: Day 1`. The Day-1 teach order is **S06 (variables) → S15 (validation & checks) → S07
  (modules)**, so input validation and plan/apply-time guardrails land immediately after
  variables and before module composition.
- **Section IDs stay stable** — import order defines teach order; S15 is not renumbered.
- The lab chain follows the deck: S15's lab lives at `labs/day-1/15-conditions-checks/`,
  extends the S06 workdir, and S07's lab extends S15's (the workdir contract,
  [0009](./0009-lab-workdirs.md)).
- S15 stays `core` tier; the tier gate ([0008](./0008-tier-canon-and-deck-headers.md)) guards
  the re-sequence.

## Consequences

- Learners meet `validation`, `precondition`/`postcondition`, and `check` while the mental model
  is still small, and every subsequent lab can use them.
- Day 1's timing budget **deepens its known overflow** (core 475 → 525 min vs the 390-min day):
  a deliberate, documented trade-off (US-X-TIME known-issue). The cut-order compensates by
  demoting S09/S10 first when a delivery needs to fit.
- Day 2's testing arc starts one section lighter and builds on already-taught assertions.
