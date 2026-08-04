# Run the slides locally

Preview the interactive Slidev decks on your laptop with Node.js. This path does
**not** need LocalStack or OpenTofu — it only serves the presentation.

The repository is locked to **pnpm** (`packageManager` in `package.json` +
`pnpm-lock.yaml`). Use the commands below as written. Plain `npm install` is not
supported (there is no `package-lock.json`).

## Prerequisites

- **Node.js 22** (LTS) — [nodejs.org](https://nodejs.org/) or a version manager
- **Corepack** (ships with Node 16.13+) to activate the pinned pnpm
- Optional: [Task](https://taskfile.dev) (`go-task`) for the `task …` aliases
- Optional: a modern browser (Chrome, Firefox, Safari, Edge)

Check versions:

```bash
node -v    # expect v22.x
corepack -v
```

## Install dependencies

From the repository root:

```bash
corepack enable
corepack prepare pnpm@11.9.0 --activate
pnpm install --frozen-lockfile
# or, if you use Task:
task setup
```

## Start the development server

Pick the deck you want:

```bash
# Via Task (preferred when installed)
task dev            # Full content superset (slides.md)
task dev:3day       # Canonical three-day cut
task dev:templates  # Theme / template gallery

# Or the underlying pnpm scripts
pnpm dev
pnpm dev:3day
pnpm dev:templates
```

Slidev prints a local URL — typically:

```text
http://localhost:3030/
```

Open that URL in your browser. Use arrow keys or the on-screen controls to move
between slides. Presenter mode is available from Slidev’s UI (often
`http://localhost:3030/presenter/`).

Stop the server with `Ctrl+C`.

## Production build and local preview

Build static SPAs (useful before changing GitHub Pages wiring):

```bash
pnpm build              # superset → dist/
pnpm build:3day         # 3-day cut (legacy /3day/ base in package script)
pnpm build:templates    # templates gallery
```

For the **exact** GitHub Pages layout (MkDocs landing + decks under `/deck/` with
hash routing), use the Pages workflow locally:

```bash
python3 -m pip install -r docs/requirements-docs.txt
pnpm pages:build        # or: task pages:build
pnpm pages:preview      # serves ./site at http://localhost:4173
```

## Related

- Toolchain and LocalStack: [setup.md](./setup.md)
- Live Pages decks and PDF releases: [downloads.md](./downloads.md)
- Facilitator delivery notes: [facilitator-runbook.md](./facilitator-runbook.md)
