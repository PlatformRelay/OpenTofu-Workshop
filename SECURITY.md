# Security Policy

## Scope

This repository ships a **Slidev slide deck, standalone Markdown labs, runnable
OpenTofu modules/examples, and the build tooling** that renders and publishes them
(Node/pnpm/Taskfile scripts, GitHub Actions workflows). "Security" here means the
security of *that project*, not a guarantee about the cloud infrastructure you deploy
while running the labs.

**Not a vulnerability report:** the labs deliberately include broken or insecure
Infrastructure-as-Code so learners can find and fix it — most notably
`labs/day-2/14-security-scanners/messy/main.tf`, which exists specifically to be
flagged by static/policy scanners as part of the lesson. That's the lab working as
designed; please don't file a security report against intentionally-vulnerable teaching
material. If you think a lab mislabels which state is "safe" vs. "vulnerable," that's a
content bug — open a normal issue instead.

## Reporting a vulnerability

If you find an actual vulnerability in the build tooling, CI workflows, a shipped
module/example, or the published site (e.g. a supply-chain issue, a path-traversal or
injection bug in a script, an exposed secret) — **do not open a public issue**. Instead
use GitHub's private reporting:

**[Report a vulnerability](https://github.com/PlatformRelay/OpenTofu-Workshop/security/advisories/new)**
(Security tab → "Report a vulnerability").

Include what you found, the affected file(s)/workflow(s), and how to reproduce it.

## Response

This is a volunteer-maintained open-source project. There's no SLA, but reports are
triaged as they come in and fixes for confirmed issues are prioritized over other work.
You'll get an acknowledgement in the advisory thread.

## Supported versions

Only the latest `main` / most recent release tag receives fixes — there is no
back-porting to older tags.
