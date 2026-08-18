# OpenTofu Workshop — Active Backlog

Canonical, execution-focused backlog. Repository history is the source for shipped-work detail.
This file intentionally keeps only active work and the minimum context needed to execute it.

## Product direction

The workshop is **beginner-first and OpenTofu-first**: learners may be new to Terraform, OpenTofu,
and HCL. Start with a small runnable project and make it grow through code transitions; teach
advanced content only after a first successful `tofu plan`/`apply`. Existing content, labs, and
assets are inputs to the redesign, not proof that the current sequence is the target state.

Reference material is available at
`/Users/A242168/Projects/Presentations/terramate/References/terraform-iac/`. Reuse ideas and
assets only after removing former consultancy branding and verifying current technical claims.

## Status legend

- **planned** — approved backlog item; implementation has not started.
- **blocked** — needs an external operator action.
- **operator** — must be performed by a human operator.

## Execution order

1. **US-P-CURRICULUM (P0, planned):** redesign the curriculum before further workshop delivery
   work. It establishes the new source sequence and may replace or re-scope previously shipped
   section content.
2. **US-P-CODEQL (P2, partially satisfied):** default CodeQL scanning is enabled; its badge is
   blocked by the lack of a stable non-404 workflow badge URL. Do not add a conflicting committed
   workflow merely to satisfy the old story wording.
3. **US-F-DEP-AUDIT (P2, planned):** add a fail-closed high/critical dependency-audit gate; the
   unpatched `image-size` exception remains a known prerequisite detail.
4. **US-P-SONAR (P3, blocked/operator):** create the correct SonarCloud project externally, then
   wire the repository to it.
5. **US-X-DRYRUN (P4, blocked/operator):** perform the delivery-readiness run only after the P0
   curriculum redesign and its follow-on implementation are complete.

Maintenance tracks may be scheduled independently when they do not alter curriculum decisions.
They must not delay recording or planning the P0 redesign.

## Active index

| ID | Title | Priority | Size | Status | Depends on |
| --- | --- | --- | --- | --- | --- |
| US-P-CURRICULUM | Beginner-first curriculum redesign | P0 | XL | planned | none |
| US-P-CODEQL | Honest CodeQL front-door status | P2 | S | partially satisfied / badge blocked | stable non-404 badge URL |
| US-F-DEP-AUDIT | Fail-closed high/critical dependency audit | P2 | M | planned | current override pins |
| US-P-SONAR | Wire SonarCloud to a real project | P3 | M | blocked / operator | create `PlatformRelay_OpenTofu-Workshop` |
| US-X-DRYRUN | Delivery-readiness dry run | P4 | M | blocked / operator | P0 redesign + implementation, core delivery material |

---

## US-P-CURRICULUM — Beginner-first OpenTofu curriculum redesign (P0) · core · XL · Days 1–3

**As a** first-time IaC learner **I want** a hands-on OpenTofu learning journey that introduces
working HCL immediately and grows one project through the workshop **so that** I can build
confidence before encountering advanced infrastructure concepts.

### Acceptance criteria

- Given the opening, when learners start Day 1, then the retained learning contract is titled
  **“What you’ll be able to build”** (or an equally concrete approved wording), and the first HCL
  plus `tofu plan` appear within the opening beginner sequence rather than after a long theory
  block.
- Given the core curriculum, when each major concept is introduced, then one runnable, evolving
  project supplies progressive code transitions, matching terminal output or existing console
  GIFs, and labs extend the same tracked files where practical.
- Given the context material, when orientation is presented, then it concisely covers IaC/DevOps
  context, Terraform history and design principles, the licensing shift and OpenTofu, and practical
  alternatives; all current facts are verified at implementation time and former consultancy
  branding is absent.
- Given the quality story, when learners reach testing and delivery, then validation,
  preconditions, postconditions, checks, testing evolution and strategies, native tests, mocks,
  CI/CD, `terraform-docs`, Gitleaks, Infracost, policy/security tooling, and pre-commit form one
  coherent progression rather than disconnected optional material.
- Given the revised deck and labs, when a beginner walkthrough is run, then the learner can explain
  the first resource, variable, output, plan, and apply before state, modules, platform tooling, or
  advanced orchestration are required. Existing console GIFs and reference-workshop visual patterns
  are inventoried; any reused visual is neutralized or recreated in the local theme.
- Given the redesign plan, when implementation is split into follow-on work, then it identifies
  the section/lab/asset changes, sequencing, verification steps, and any claims requiring fresh
  source checks. It does not silently alter technical claims or copy former branding.

### Done when

- [ ] The current workshop, labs, console GIFs, and reference material have been compared and the
  executable redesign plan is recorded in the canonical planning context.
- [ ] Follow-on implementation stories are sequenced from the plan; no slide/lab implementation is
  included in this planning story.
- [ ] The deck manifest, facilitator timing, labs, and verification gates are explicitly accounted
  for in the implementation sequence.

**Touches:** canonical planning context, then explicitly scoped follow-on stories.
**Depends on:** none.
**Not in scope:** changing slides, labs, code, or technical-version claims in this planning story.
**Sequence:** first active curriculum item; precedes US-X-DRYRUN.

## US-P-CODEQL — Honest CodeQL front-door status (P2) · recommended · S

**Status:** default setup is enabled as of 2026-08-13. A committed `codeql.yml` would conflict
with that setup, and GitHub’s workflow badge URL currently returns 404.

**Outcome:** keep CodeQL scanning enabled and keep the README/docs badge absent until a stable,
non-404 badge target exists. Do not create a duplicate workflow solely for the badge.

**Depends on:** a stable CodeQL badge target or an approved alternative status representation.
**Not in scope:** changing the default CodeQL setup without an operator decision.

## US-F-DEP-AUDIT — Fail-closed high/critical dependency audit (P2) · recommended · M

**As a** maintainer **I want** CI to fail on unexcepted high/critical npm advisories **so that**
known vulnerable dependencies cannot merge silently.

### Acceptance criteria

- A required CI gate parses `pnpm audit --json` and fails closed on unavailable or malformed data
  as well as unexcepted high/critical findings.
- Exceptions require an advisory ID, reason, owner, and unexpired ISO date; expired or malformed
  exceptions fail the gate.
- The remaining `image-size` advisories are rechecked at implementation time and documented only
  while no patched release exists; a patch replaces the exception.
- Tests cover unexcepted, missing, and expired-exception failures.

**Depends on:** current override pins (already landed).
**Not in scope:** blocking moderate/low advisories or replacing Renovate.

## US-P-SONAR — Wire SonarCloud once a real project exists (P3) · optional · M

**Status:** blocked. The organization has no `PlatformRelay_OpenTofu-Workshop` project; the
previous typo key also does not exist.

### Acceptance criteria

- The operator creates the correctly named SonarCloud project.
- CI uses that exact key and fails honestly if it is missing or incorrect.
- The first analysis is triaged, and any README/docs badge is live or intentionally omitted with
  a matching front-door assertion.

**Depends on:** external operator creation of `PlatformRelay_OpenTofu-Workshop`.
**Not in scope:** creating or administering the SonarCloud project from the repository.

## US-X-DRYRUN — Delivery-readiness dry run (P4) · core · M

**Status:** operator-only and deferred until the P0 redesign and its implementation are complete.

**Outcome:** run the selected delivery cut end to end against the timing budget, record measured
times, and treat any fresh-machine lab failure as a release blocker.

**Depends on:** US-P-CURRICULUM follow-on implementation, core material, facilitator runbook, and
the delivery-validation documentation.

## Completed-history pointer

M0–M6 content, quality work, and ecosystem appendices were previously shipped. Use Git history
for implementation and merge evidence; do not re-expand completed narratives here unless they
become active again.
