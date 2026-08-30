# ADR 0016: Authoring contract in `docs/`, thin `AGENT.md` shim, ignore-file hygiene

- **Status:** accepted
- **Scope:** where the authoring contract lives, what tracked files may point at,
  and how `.gitignore` documents its entries. Complements
  [0002](0002-repository-and-content-structure.md), which established that
  planning material is gitignored under `agent-context/`.

## Context

The authoring contract (guardrails, repository map, design system, lab and drift
contracts, Definition of Done, presenter-notes and commit conventions) lived in
a repo-root `AGENT.md`. Three problems, surfaced by the 2026-08-30 audit
(OSS-6/ARCH-4/ARCH-6):

1. **Wrong signal.** The rules bind *human* contributors too, but a file named
   `AGENT.md` reads as AI-agent instructions, so humans skip it.
2. **Dangling pointers.** It referenced `agent-context/` planning files that are
   gitignored by design ([0002](0002-repository-and-content-structure.md)) and
   therefore absent from every fresh clone. Likewise, gate names such as
   `US-F-TIERS` in `Taskfile.yaml`, `scripts/verify.sh`, and CI referenced an
   invisible backlog with no tracked legend.
3. **Narrative ignore file.** `.gitignore` carried multi-paragraph session
   rationale (worktree staging hazards, the verify-lock trailing-`*` analysis)
   that belongs in a durable record, not in a config file. It also un-ignored a
   nonexistent `AGENTS.md`.

## Decision

- The authoring contract lives in **`docs/authoring-guide.md`** — tracked,
  human-named, published in the MkDocs nav. Pure relocation: contract content is
  unchanged; the repository map is completed to cover every top-level directory.
- **`AGENT.md` stays as a thin shim** (agent entry point + section-to-anchor
  routing table + operational notes), so existing "`AGENT.md` · *section*"
  references and the README front-door route keep resolving.
- **Tracked files must not point into gitignored paths.** References to
  `agent-context/` content are removed from tracked prose; the directory itself
  may be *described* (here and in [0002](0002-repository-and-content-structure.md))
  as the untracked planning space, but no tracked file may direct a reader to a
  file inside it.
- **`US-*` gate names get a tracked legend** (authoring guide · repository map):
  they are the backlog-story IDs that introduced each gate — stable, opaque
  labels; the backlog itself stays untracked.
- **`.gitignore` entries carry one-line comments**; durable rationale lives here:
  - `/.worktrees/` — legacy sibling-worktree root. Agent worktrees live under
    `.claude/` (ignored), but the older root still occurs; if unignored, one
    `git add -A` stages another lane's entire tree, including its copy of the
    deliberately-unformatted S13 fixture.
  - `/.verify.lock*` — `scripts/verify.sh` concurrency-guard lock (US-F-GATEHYG),
    created per run and removed on exit; without the entry the tree reads dirty
    while any verify runs, and several gates use clean porcelain as evidence.
    The trailing `*` is load-bearing: a SIGKILL between the guard's `mv` and
    re-`mkdir` strands a `.verify.lock.stale.<pid>` sidecar with no reaper, and
    a bare `/.verify.lock` measurably does not ignore it. The leading `/` keeps
    it root-anchored so a nested `sub/.verify.lock` is still caught.
  - The `!AGENTS.md` un-ignore was removed — no `AGENTS.md` exists and no
    pattern ignores it; the line was inert.

## Consequences

- A fresh clone contains every path a tracked file references; "no
  `agent-context/` pointers in tracked prose" is grep-testable.
- Referrers cite `docs/authoring-guide.md` (or an anchor in it); the shim keeps
  old citations one hop from the content. `README.md` / `CONTRIBUTING.md` still
  link `AGENT.md` until their owning lane repoints them — both resolve either way.
- Moving the guide again requires updating the shim's routing table and the
  referrers enforced by `pnpm link-check`.
