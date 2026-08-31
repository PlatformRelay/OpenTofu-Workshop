# Roadmap

Where the **OpenTofu Practitioner Workshop** is heading, and how to influence
that. This document describes **direction, not commitments**: items are
*planned* (a maintainer intends to do them) or *exploring* (under
consideration, shape not settled). There are no dates — the project ships when
things are ready, and has released roughly every one to two weeks since
`v0.1.0` (July 2026); the latest release is
[`v0.6.0`](https://github.com/PlatformRelay/OpenTofu-Workshop/releases/latest)
(August 2026).

## Where the project stands

The workshop is **content-complete for its three-day arc**: all sections
(`S00`–`S28`), a standalone lab per section, the capstone, the
[facilitator runbook](docs/facilitator-runbook.md), and three composed decks
(superset, canonical three-day cut, template gallery) are shipped — see the
[README](README.md) for the tour. The honest caveats live in
[Known limitations](docs/beta-limitations.md): the library is deliberately a
superset that overflows three days, and the minute marks are planning
estimates, not measured timings.

## Near-term themes (planned)

Sanitized from the maintainer's working backlog; each item below is real,
scoped work — not aspiration.

### 1. Content depth

Deepening the existing curriculum rather than widening it:

- **Iteration and refactoring depth** — `for_each` / `count` / dynamic blocks,
  and `moved` / `removed` refactoring, in the authoring part and its lab.
- **Import and state adoption** — a lab that adopts pre-existing (LocalStack)
  resources into state.
- **State in practice** — a hands-on drift experience step, and a remote-state
  (S3 backend) stretch goal.
- **Migration beat** — a Terraform-to-OpenTofu migration moment in the
  canonical cut, building on the differentiators the deck already teaches.
- **Participant quizzes** — a per-section quiz bank, building on the
  [quiz spike ADR](docs/decisions/0015-participant-quiz-spike.md).
  Community contributions are explicitly welcome here — see
  [issue #22](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/22).
- **Capstone build variant** — a from-scratch alternative to the current
  guided capstone.

### 2. Community and contribution experience

Making the project genuinely easy to adopt and contribute to:

- **Issue forms** — proper bug and idea templates plus a chooser, so
  reporting doesn't require insider context.
- **Contributor docs in one obvious place** — moving the authoring contract
  into `docs/` per
  [ADR 0016](docs/decisions/0016-authoring-contract-home.md), so tracked
  files never point at paths that don't exist in a fresh clone.
- **Zero dead links on the published site** — fixing the remaining live-404
  links and teaching the link gate to catch that class permanently.
- **Lighter pages** — compressing the AI-generated section cover imagery
  (WebP) so clones and page loads get cheaper.

### 3. Engineering hygiene

Keeping the gates honest (this project treats green-but-meaningless checks as
defects):

- **Release workflow hardening** — serializing tag-triggered release runs so
  a tag push can't race itself.
- **Setup diagnostics** — `setup/bootstrap.sh` naming the tool whose version
  probe failed instead of exiting silently.
- **Compile what we ship** — building and vetting the Terratest Go code in
  CI, and validating every Day-2 lab working directory (not only the ones
  with `tofu test` suites).

## Exploring (no commitment yet)

- **Day-1 timing rebalance** — the Day-1 overflow is a known, documented
  trade-off ("choice over fit"). Rebalancing is deliberately parked until
  real delivery data exists; if you run the workshop, sharing timings via
  [issue #21](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/21)
  is the single most useful thing you can do to unblock this.

## How to influence this roadmap

- **Pick up a starter issue** — the
  [`good first issue`](https://github.com/PlatformRelay/OpenTofu-Workshop/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
  and
  [`help wanted`](https://github.com/PlatformRelay/OpenTofu-Workshop/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
  labels mark self-contained work seeded from this roadmap.
- **Propose or report** —
  [open an issue](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/new/choose)
  for something concrete, or start a
  [Discussion](https://github.com/PlatformRelay/OpenTofu-Workshop/discussions)
  for an idea or question. Small fixes skip all ceremony — see the fast path
  in [CONTRIBUTING.md](CONTRIBUTING.md).
- **Share delivery experience** — timing data
  ([#21](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/21)) and
  quiz questions
  ([#22](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/22)) are
  standing asks.

This file is updated as themes land or change direction; the record of what
*has* shipped lives in the
[release notes](https://github.com/PlatformRelay/OpenTofu-Workshop/releases).
