# Contributing

Thanks for considering a contribution to the **OpenTofu Practitioner Workshop**. This is
a free, vendor-neutral, community-facing project — fixes, feedback, and new content are
all welcome.

## Small fix? Fast path

Typo, broken link, wrong command, small doc fix — **just open a PR.** That's the whole
process:

- **No required reading.** You do not need `AGENT.md` or the rest of this document.
- **No commit-message conventions.** Write any commit message; maintainers will
  squash-merge and format the final message themselves.
- **No local toolchain.** Editing the file on github.com is fine — CI is the safety
  net (markdown lint on labs, an offline link check on README/docs/labs, and a strict
  docs-site build all run on every PR).
- **In the PR description**, one sentence is enough — delete the template checklist.

One hard rule still applies even to one-liners: no employer, customer, or corporate
brand names, and no tooling/AI attribution in content or commit messages.

Everything below this section is the contract for **substantive changes** — slides,
labs, HCL modules, scripts. If that's you, read on.

## Ways to contribute

- **Report a bug or content issue** —
  [open an issue](https://github.com/PlatformRelay/OpenTofu-Workshop/issues/new/choose).
- **Ask a question or propose an idea** — start a
  [GitHub Discussion](https://github.com/PlatformRelay/OpenTofu-Workshop/discussions).
  If there's something concrete to fix, open an issue instead.
- **Fix something small** — typos, broken links, a wrong command, a slide overflow —
  use the [fast path](#small-fix-fast-path) above: open a PR directly.
- **Propose a new section, lab, or module** — open a Discussion or issue first
  describing the scope; sections must be self-contained per `AGENT.md`, so it's worth
  agreeing on shape before investing in a full draft.
- **Report a security issue** — see [`SECURITY.md`](./SECURITY.md), not a public issue.

## Docs-only setup

Working only on prose — `docs/`, lab text, README? You don't need Docker, Go, OpenTofu,
or Bash 4. The minimum, honestly, is **nothing**: push the change and CI runs every
docs gate for you. If you want to run them locally first, each is Docker-free and works
on stock macOS:

| Check | What it needs | Command |
| --- | --- | --- |
| Markdown lint (`labs/**/*.md` only — deck sources are excluded by design) | Node ≥ 22 + pnpm | `pnpm install && pnpm lint` |
| Offline link check (README, `docs/`, `labs/`) | Node only, zero install | `node scripts/link-check.mjs` |
| Docs-site preview / strict build | Python 3 | `python3 -m pip install -r docs/requirements-docs.txt && mkdocs serve` (CI runs `mkdocs build --strict`) |

Note: CI has no path filters, so a docs-only PR still runs the full job matrix (HCL
validation, deck builds, shell tests, …) — but those jobs run against code you didn't
touch and pass on their own. The jobs that actually exercise a prose change are
**lint**, **link-check**, **lab-contract**, and **pages-contract**; those four are
the ones to watch.

## Substantive changes: the full contract

For slides, labs, HCL modules, scripts, and tooling, the expectations below apply in
full.

### Before you start

- **Read [`AGENT.md`](./AGENT.md) first.** It is the authoring contract: deck
  architecture, section structure, the presenter-notes convention, module/lab
  authoring rules, and commit conventions. Every substantive PR is expected to follow
  it.
- **Know the map.** [`README.md`](./README.md) is the project front door and
  [`docs/facilitator-runbook.md`](./docs/facilitator-runbook.md) covers running the
  room. [`docs/decisions/`](./docs/decisions/) holds the ADRs behind non-obvious
  choices (e.g. the toolchain lanes in
  [ADR 0011](./docs/decisions/0011-toolchain-lanes.md)).

### Local setup

```bash
git clone https://github.com/PlatformRelay/OpenTofu-Workshop.git
cd OpenTofu-Workshop
task setup          # detect/install the workshop toolchain and deck dependencies
task dev:3day        # serve the canonical workshop at localhost:3030
```

No `task`? The underlying commands are plain `pnpm`, `tofu`, and Docker Compose — see
[`Taskfile.yaml`](./Taskfile.yaml) for their exact definitions.

### Before opening a PR

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
