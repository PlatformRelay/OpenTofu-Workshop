# Contributing

Thanks for considering a contribution to the **OpenTofu Practitioner Workshop**. This is
a free, vendor-neutral, community-facing project — fixes, feedback, and new content are
all welcome.

## Before you start

- **Read [`AGENT.md`](./AGENT.md) first.** It is the authoring contract: deck
  architecture, section structure, the presenter-notes convention, module/lab
  authoring rules, and commit conventions. Every PR is expected to follow it.
- **Know the map.** [`README.md`](./README.md) is the project front door and
  [`docs/facilitator-runbook.md`](./docs/facilitator-runbook.md) covers running the
  room. [`docs/decisions/`](./docs/decisions/) holds the ADRs behind non-obvious
  choices (e.g. the toolchain lanes in
  [ADR 0011](./docs/decisions/0011-toolchain-lanes.md)).

## Ways to contribute

- **Report a bug or content issue** —
  [open an issue](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/new/choose).
- **Ask a question or propose an idea** — use
  [GitHub Discussions](https://github.com/PlatformRelay/OpenTofu-Workshop/discussions)
  if there's nothing concrete to fix yet.
- **Fix something small** — typos, broken links, a wrong command, a slide overflow —
  open a PR directly.
- **Propose a new section, lab, or module** — open a Discussion or issue first
  describing the scope; sections must be self-contained per `AGENT.md`, so it's worth
  agreeing on shape before investing in a full draft.
- **Report a security issue** — see [`SECURITY.md`](./SECURITY.md), not a public issue.

## Local setup

```bash
git clone https://github.com/PlatformRelay/OpenTofu-Workshop.git
cd OpenTofu-Workshop
task setup          # detect/install the workshop toolchain and deck dependencies
task dev:3day        # serve the canonical workshop at localhost:3030
```

No `task`? The underlying commands are plain `pnpm`, `tofu`, and Docker Compose — see
[`Taskfile.yaml`](./Taskfile.yaml) for their exact definitions.

## Before opening a PR

```bash
task verify          # fmt, validation, tofu tests, documentation contracts
task lab:up           # start LocalStack if your change touches a lab that needs it
task lab:terratest DIR=labs/fixtures/terratest-smoke   # if you touched Terratest fixtures
```

`task verify` needs **Bash ≥4** — macOS's default `/bin/bash` (3.2) fails; put
Homebrew bash 5 first on `PATH`.

**Guardrails checklist** (from `AGENT.md`, non-negotiable):

- No employer, customer, or corporate brand names anywhere.
- No tooling/AI attribution in content or commit messages (no `Co-Authored-By`).
- Any AI-generated image carries a visible "AI generated" footer.
- Teach `tofu`, not a parallel Terraform track (Terraform compatibility is a note, not a
  second curriculum).
- Commit messages follow `<gitmoji> <type>(<scope>): <subject>` (see `AGENT.md` for the
  full convention and examples).

## Code of Conduct

This project follows the [Code of Conduct](./CODE_OF_CONDUCT.md). By participating,
you're expected to uphold it.

## License

Contributions are accepted under the project's [0BSD License](./LICENSE) — the same
terms as the rest of the repository.
