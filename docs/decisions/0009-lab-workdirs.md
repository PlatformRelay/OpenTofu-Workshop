# 0009 — Labs use in-repo tracked workdirs

**Status:** Accepted

## Context

Early labs (notably lab 05) had learners paste heredocs into `$HOME` — self-contained, but
**unverifiable**: nothing tied the HCL a slide teaches to the HCL a learner applies, so the
"slide ↔ lab single source of truth" contract (ADR [0007](./0007-validation-and-ci.md)'s smoke
lane) stayed aspirational. Decision **D2 (2026-07-11)** chose tracked workdirs; US-0-LABDIRS
built the enforcement and US-F-LAB05 retrofitted the one pre-convention lab.

## Decision

- A lab's runnable HCL lives as **tracked files in a sibling workdir**: for
  `labs/day-N/NN-topic.md` the config lives under `labs/day-N/NN-topic/` (e.g.
  `labs/day-1/05-state-encryption/main.tf`), referenced **by path** from the prose. The
  heredoc-into-`$HOME` pattern is never the primary flow.
- A fenced ```hcl block is tied to its source file with an HTML-comment marker
  (`<!-- source: labs/… -->`) on the line above the fence. `scripts/verify.sh` **byte-diffs**
  every annotated block against its file and fails the build, naming the file, on any drift or
  missing file. Unannotated blocks warn (scratch/in-flight content never blocks unrelated lanes).
- Line endings are LF, enforced by the repo-root `.gitattributes`; the drift check strips `\r`
  upstream so a stray CRLF cannot silently disarm detection.
- `labs/fixtures/` is a carve-out reserved for the drift self-test fixtures — an intentional
  exception to the `labs/day-N/NN-topic` convention, never numbered into the section namespace.
- The enforcement ships a **committed fail-path self-test** (`scripts/verify-selftest.sh`, run by
  `task verify`) proving the check is armed, not decorative.

## Consequences

- `task lab:validate DIR=labs/day-N/NN-topic` works against real, `tofu fmt`-clean files; what CI
  verified is exactly what a learner applies.
- Slide/lab HCL is generated *from* the tracked file, never hand-synced; drift is a build failure.
- Successive labs can extend the previous lab's workdir (e.g. S06 → S15 → S07), keeping one
  continuous, verified configuration across a day.
- Authoring rules live in `AGENT.md` ("Lab workdir & drift contract").
