# Cutting a release

Ordinary pushes never release. Only a `v*` tag triggers
[`.github/workflows/release.yml`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/.github/workflows/release.yml).

## What a release ships

| Artifact | Source |
| --- | --- |
| `opentofu-workshop-full-<tag>.pdf` | Superset (`slides.md`) |
| `opentofu-workshop-3day-<tag>.pdf` | Three-day cut (`slides-3day.md`) |

## How to cut

```bash
git checkout main && git pull --ff-only
# Confirm CI is green for the tip you intend.
git tag v1.2.0
git push origin v1.2.0   # → Release workflow exports PDFs
```

## GitHub Pages (docs + decks)

Every push to `main` (and manual `workflow_dispatch`) runs
[`.github/workflows/pages.yml`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/.github/workflows/pages.yml):
MkDocs Material at `/`, hash-routed Slidev under `/deck/`. Locally:

```bash
python3 -m pip install -r docs/requirements-docs.txt
task pages:build
task pages:preview   # http://localhost:4173
```
