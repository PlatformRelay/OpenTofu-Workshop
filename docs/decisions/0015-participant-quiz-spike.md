# ADR 0015: Participant quiz prototype — schema and offline delivery first

- **Status:** proposed
- **Scope:** portable section-quiz content ownership, offline facilitator fallback, and the decision
  boundary before any live quiz platform is selected for the OpenTofu practitioner workshop.

## Context

The workshop needs formative checks tied to section learning objectives. Quiz content must remain
version-controlled, reviewable, and independent of Slidev slides. A sibling spike in
kubernetes-workshop ([ADR 0011](https://github.com/PlatformRelay/kubernetes-workshop/blob/main/docs/decisions/0011-live-quiz-spike.md))
evaluated live FOSS runtimes and deferred adoption until a complete-runtime license gate passes.

This spike (US-P-QUIZ) establishes the same **content-first** pattern for OpenTofu: a JSON schema,
prototype bank, validation gate, and offline participant/facilitator export. It does **not** select
or deploy a live quiz platform.

## Options considered

### Adopt a live quiz platform now

Would provide anonymous room participation and aggregate results. Requires runtime selection, FOSS
license attestation, facilitator-owned deployment topology, and venue-network validation — none of
which are in scope for this spike.

### Repository schema with offline export only (chosen for this spike)

Keeps curriculum ownership in git, enables review and CI validation, and provides a show-of-hands /
printed fallback without binding to a vendor API or Kubernetes add-on.

### Embed questions in Slidev

Would couple quiz content to deck generation and complicate reuse across delivery cuts and exports.

## Decision

1. Keep quiz content in `quiz/questions.schema.json` and the versioned prototype bank under `quiz/`.
2. Enforce AJV schema validation plus semantic checks (canonical section membership from
   `scripts/deck-manifest.mjs`, unique IDs, answer-to-option references) via `pnpm quiz:validate`.
3. Emit separate participant and facilitator Markdown via `pnpm quiz:export`; participant files must
   not contain answers.
4. **Platform selection stays explicitly open.** No live service, adapter integration, or CI wiring
   beyond the prototype scripts is introduced by this ADR. A future ADR must record immutable
   evidence before any runtime is adopted.

## Consequences

- Question authoring can proceed without choosing Claper, ClassQuiz, QuizDock, or another platform.
- The three prototype questions (S03, S04, S07) are examples, not full section coverage.
- Facilitators can use offline exports until a later ADR accepts a live runtime.
- US-P-QUIZ does not modify `ci.yml`, pages build, or Taskfile lanes; integration is a follow-up story.
