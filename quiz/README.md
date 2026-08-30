# Portable question bank

This directory is the candidate-neutral source for the workshop's per-section self-checks. It is
version-controlled curriculum content, not a quiz vendor's database, and is not embedded in Slidev.

- `questions.schema.json` documents schema version 1.
- `questions.json` is the question bank: every `canonical: true` section in
  `scripts/deck-manifest.mjs` carries at least 3 questions (the validator enforces this floor).
- Stable question and option IDs survive export so result data can be related to curriculum content.
- Correct answers, explanations, distractor rationales, learning objectives, and currency references
  live in the repository.

Run the gates and offline exports with:

```sh
pnpm quiz:validate           # AJV schema + semantic checks + canonical coverage floor
pnpm test:quiz               # validator/export behaviour tests
pnpm quiz:export             # full bank -> dist-quiz/participant.md + facilitator.md
pnpm quiz:export --day 2     # day self-check -> participant-day-2.md + facilitator-day-2.md
```

AJV enforces `questions.schema.json`; the validator then applies semantic relationships that JSON
Schema does not express: canonical section membership (non-canonical or unknown sections are named
errors), unique IDs, answer-to-option references, and the >=3-questions-per-canonical-section floor.
CI runs `quiz:validate` and `test:quiz` as blocking steps in the lint job
(`tests/shell/ci-contract.bats` guards the wiring).

The export command creates separate participant and facilitator Markdown; with `--day` it resolves
that day's canonical sections from the deck manifest (never a hand-maintained list) and fails with a
named error for an invalid day or a day the bank does not cover. Participant output deliberately
omits answers. The facilitator output can be printed or used for a show-of-hands fallback when a
live service or venue internet is unavailable.

Platform selection for live delivery remains open; see
[ADR 0015](../docs/decisions/0015-participant-quiz-spike.md).
