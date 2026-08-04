---
hide:
  - navigation
  - toc
  - title
---

# OpenTofu Practitioner Workshop

**A free, open-source, vendor-neutral Infrastructure as Code workshop** — Slidev
presentations and LocalStack-backed labs. Use it to learn yourself, to teach
colleagues, or to run a full multi-day delivery. Adapt it, restyle it, redistribute
it under the [0BSD License](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/LICENSE)
(no attribution required).

<p markdown="1">

[![CI](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/ci.yml/badge.svg)](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/ci.yml)
[![Pages](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/pages.yml/badge.svg)](https://github.com/PlatformRelay/OpenTofu-Workshop/actions/workflows/pages.yml)
[![Release](https://img.shields.io/github/v/release/PlatformRelay/OpenTofu-Workshop)](https://github.com/PlatformRelay/OpenTofu-Workshop/releases)
[![License: 0BSD](https://img.shields.io/github/license/PlatformRelay/OpenTofu-Workshop)](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/LICENSE)

</p>

**Live decks:** [Superset](https://platformrelay.github.io/OpenTofu-Workshop/deck/) ·
[3-day cut](https://platformrelay.github.io/OpenTofu-Workshop/deck/3day/) ·
[Templates](https://platformrelay.github.io/OpenTofu-Workshop/deck/templates/)

[Interactive decks :octicons-arrow-right-24:](downloads.md#interactive-slidev-decks){ .md-button .md-button--primary }
[PDF downloads :octicons-download-24:](downloads.md#pdf-downloads){ .md-button }
[Run locally :octicons-terminal-24:](run-slides.md){ .md-button }

## Why this workshop

| | |
| --- | --- |
| **Free** | No paywall, no account, no telemetry. Clone it and go. |
| **Teach-ready** | Decks + labs + a [facilitator runbook](facilitator-runbook.md) so you can deliver IaC to colleagues. |
| **Hands-on** | Roughly half the time is labs — LocalStack or `mock_provider`, **no cloud bill**. |
| **Flexible delivery** | Solo learning, a custom cut from the superset, or the canonical three-day path. |
| **Many formats** | Live Slidev in the browser, local Node.js preview, and downloadable PDFs. |
| **Yours to adapt** | Restyle the theme, reorder sections, fork or sell freely under 0BSD. |

## Start here

| Goal | Go to |
| --- | --- |
| Preview the slides in the browser | [Live decks](downloads.md#interactive-slidev-decks) |
| Download PDF handouts | [PDF downloads](downloads.md#pdf-downloads) / [GitHub Releases](https://github.com/PlatformRelay/OpenTofu-Workshop/releases) |
| Run Slidev on your laptop | [Run the slides locally](run-slides.md) |
| Install tools + LocalStack | [Local toolchain & LocalStack](setup.md) |
| Do the labs | [Labs index](labs.md) · [Lab 00](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/00-setup.md) |
| See the full section map | [Syllabus](syllabus.md) |
| Facilitate a room | [Facilitator runbook](facilitator-runbook.md) |

## Curriculum spine

The learning journey follows how infrastructure grows in practice —
Author → Test → Scale:

1. **Author** — HCL, plan/apply, state, encryption, validation, modules, naming.
2. **Test** — static checks, scanners, `check` blocks, `tofu test`, mocks, CI.
3. **Scale** — Terramate stacks, generation, orchestration, change detection.

Full map: [syllabus](syllabus.md).
