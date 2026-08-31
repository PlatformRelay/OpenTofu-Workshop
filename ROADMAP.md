# Roadmap

Where the **OpenTofu Practitioner Workshop** is heading, and how to influence
that. This document describes **direction, not commitments**: items are
*planned* (a maintainer intends to do them) or *exploring* (under
consideration, shape not settled). There are no dates — the project ships when
things are ready. `v0.1.0` shipped in July 2026 and regular releases have
followed since; see the
[latest release](https://github.com/PlatformRelay/OpenTofu-Workshop/releases/latest)
for where things stand today.

## Where the project stands

The workshop is **content-complete for its three-day arc**: all sections
(`S00`–`S28`), a standalone lab per section, the capstone, the
[facilitator runbook](docs/facilitator-runbook.md), and three composed decks
(superset, canonical three-day cut, template gallery) are shipped — see the
[README](README.md) for the tour.

Beyond that core arc, recent releases have also landed a depth-and-polish
wave:

- **Content depth** — iteration (`for_each` / `count` / dynamic blocks) and
  refactoring (`moved` / `removed`) depth in the best-practices section and
  its lab, an import/state-adoption lab against LocalStack, a hands-on drift
  step and an S3-backend stretch in the state lab, a Terraform-to-OpenTofu
  migration beat in the canonical cut, a per-section
  [quiz bank](quiz/README.md), and a build-variant capstone.
- **Community packaging** — bug and idea
  [issue forms](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/new/choose)
  with a chooser, and the [authoring guide](docs/authoring-guide.md) as a
  tracked contributor contract per
  [ADR 0016](docs/decisions/0016-authoring-contract-home.md), so tracked
  files never point at paths that don't exist in a fresh clone.
- **Engineering hygiene** — serialized (non-racing) release runs, setup
  diagnostics that name the tool whose version probe failed, `go vet` over
  the Terratest Go code in CI, and a validate sweep over every Day-2 lab
  working directory.
- **Site link integrity** — the published site carries no known dead links:
  docs pages that pointed outside the docs tree (for example the lab links
  in [the rehearsal checklist](docs/rehearsal-checklist.md)) now use
  GitHub-absolute links, and the offline link checker gates the whole class —
  site-URL and GitHub-absolute self links are resolved against the tree,
  docs-escaping relative links fail the build, and untracked `.terraform`
  caches are skipped during discovery.

The honest caveats live in
[Known limitations](docs/beta-limitations.md): the section library is
deliberately a superset that overflows three days, and the minute marks are
planning estimates, not measured timings.

## Near-term (planned)

Genuinely open work, verified against the tree — not aspiration. Nothing is
queued right now: the previous item here (zero dead links on the published
site) shipped and moved into the section above. New items are added as they
are verified open against the tree.

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
