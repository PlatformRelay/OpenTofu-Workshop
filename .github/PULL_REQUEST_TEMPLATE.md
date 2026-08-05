## What & why

<!-- One or two sentences: what changed, and why. Link an issue/Discussion if there is one. -->

## Type of change

- [ ] Content (slide/section text, diagram, lab)
- [ ] New section, lab, or module
- [ ] Docs (README, facilitator runbook, ADR)
- [ ] Tooling / CI / Taskfile
- [ ] Fix (broken command, wrong output, overflow, link)

## Checklist

- [ ] Read [`AGENT.md`](../AGENT.md) and followed the relevant contract (deck
      architecture / lab / module authoring rules, as applicable).
- [ ] No employer, customer, or corporate brand names.
- [ ] No tooling/AI attribution in content or commit messages (no `Co-Authored-By`).
- [ ] Any AI-generated image carries a visible "AI generated" footer.
- [ ] Teaches `tofu` (not a parallel Terraform track).
- [ ] Commit messages follow `<gitmoji> <type>(<scope>): <subject>`.
- [ ] Ran `task verify` (fmt, validation, tofu tests, documentation contracts).
- [ ] If a lab needs LocalStack: ran `task lab:up` and exercised the lab against it.

## Notes for reviewers

<!-- Anything a reviewer should know: known limitations, follow-up work, what wasn't
tested and why. -->
