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

## Local development surface

LocalStack's edge port is published on the loopback interface only
(`127.0.0.1:4566:4566` in `docker-compose.yml`). LocalStack accepts any
credentials, so a `0.0.0.0` bind would let anyone on the same network use a
learner's laptop as an unauthenticated AWS emulator, read what the labs put in
it, and plant state for the next lab to trip over. Nothing in the labs needs a
non-loopback address: hosts talk to `localhost:4566`, and the `terratest`
service reaches the container over the compose network, which a host-port
binding does not restrict. If a lab ever needs LocalStack from another machine,
put an authenticated proxy in front rather than widening this bind.

## Branch protection

`main` is governed by the ruleset in `.github/rulesets/protect-main.json`:
rebase-only merges, linear history, every CI job green, and one approving
review, with repository admins as the bypass actor so the maintainer's own
lanes still land. The file is the record; GitHub holds the live copy. To apply
or re-apply it:

```sh
gh api -X POST repos/PlatformRelay/OpenTofu-Workshop/rulesets \
  --input .github/rulesets/protect-main.json
```

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
