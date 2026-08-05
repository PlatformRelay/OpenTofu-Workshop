# Live decks & PDF downloads

## Interactive Slidev decks

These are the always-current GitHub Pages builds (hash-routed under `/deck/` so
slide navigation and hard refreshes work on project Pages).

| Deck | URL |
| --- | --- |
| **Documentation home** (this site) | <https://platformrelay.github.io/OpenTofu-Workshop/> |
| Full content **superset** | <https://platformrelay.github.io/OpenTofu-Workshop/deck/> |
| Canonical **3-day cut** | <https://platformrelay.github.io/OpenTofu-Workshop/deck/3day/> |
| **Day 1** entry | <https://platformrelay.github.io/OpenTofu-Workshop/deck/day-1/> |
| **Day 2** entry | <https://platformrelay.github.io/OpenTofu-Workshop/deck/day-2/> |
| **Day 3** entry | <https://platformrelay.github.io/OpenTofu-Workshop/deck/day-3/> |
| **Template gallery** | <https://platformrelay.github.io/OpenTofu-Workshop/deck/templates/> |

Deep-link to a slide with a hash fragment, for example
`…/deck/day-1/#/5` for slide 5 of Day 1.

Compatibility redirects: legacy `/3day/` and `/templates/` paths forward to the
`/deck/…` locations above (bookmarks from the pre-MkDocs layout still work).

## PDF downloads

Every `v*` GitHub Release publishes PDF exports of the live delivery decks (and an
offline site zip). Prefer the **latest release** page so links stay current across tags:

- **All release assets:** [GitHub Releases](https://github.com/PlatformRelay/OpenTofu-Workshop/releases)
- **Latest:** [Releases · latest](https://github.com/PlatformRelay/OpenTofu-Workshop/releases/latest)

Typical artifact names (tag substituted for `<tag>`):

| Artifact | Contents |
| --- | --- |
| `opentofu-workshop-day-1-<tag>.pdf` | Day 1 live entry |
| `opentofu-workshop-day-2-<tag>.pdf` | Day 2 live entry |
| `opentofu-workshop-day-3-<tag>.pdf` | Day 3 live entry |
| `opentofu-workshop-full-<tag>.pdf` | Full content superset (`slides.md`) |
| `opentofu-workshop-3day-<tag>.pdf` | Canonical three-day cut (`slides-3day.md`) |
| `opentofu-workshop-site-<tag>.zip` | Offline HTML bundle |

How tags are cut: [release.md](./release.md).

## Labs

| Resource | Link |
| --- | --- |
| Labs by day (this site) | [labs.md](./labs.md) |
| Lab 00 (start here) | [labs/day-1/00-setup.md](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/00-setup.md) |
| Labs tree | [labs/](https://github.com/PlatformRelay/OpenTofu-Workshop/tree/main/labs) |
