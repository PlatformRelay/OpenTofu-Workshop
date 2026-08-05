# Portable quiz prototype

This directory is the candidate-neutral source for the US-P-QUIZ participant quiz spike. It is not a
complete question bank and is not embedded in Slidev.

- `questions.schema.json` documents schema version 1.
- `questions.prototype.json` exercises the schema across S03, S04, and S07.
- Stable question and option IDs survive export so result data can be related to curriculum content.
- Correct answers, explanations, distractor rationales, learning objectives, and currency references
  live in the repository, not in a quiz vendor's database.

Run the prototype gates and offline fallback with:

```sh
pnpm quiz:validate
pnpm test:quiz
pnpm quiz:export
```

AJV enforces `questions.schema.json`; the validator then applies semantic relationships that JSON Schema
does not express, including canonical section membership, unique IDs, and answer-to-option references.

The export command creates separate participant and facilitator Markdown. Participant output deliberately
omits answers. The facilitator output can be printed or used for a show-of-hands fallback when a live
service or venue internet is unavailable.

Platform selection for live delivery remains open; see [ADR 0015](../docs/decisions/0015-participant-quiz-spike.md).
