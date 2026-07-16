# Branding assets

The workshop's favicon set, logos, and OG / social-preview cards, landed by the branding
branches (favicon+social, repo/workshop logo, Kollect-style social cards) and **wired in
2026-07-16 (US-X-BRAND)**.

| File | Wired where |
| --- | --- |
| `favicon-32.png` | Primary favicon — `favicon:` headmatter of all three root decks |
| `favicon.ico`, `favicon-180.png` | Legacy `.ico` + apple-touch icon links — root `index.html` (merged into every deck's `<head>`) |
| `logo-512.png` | Cover-slide logo mark — `logo:` frontmatter on each root deck's cover (`theme/layouts/cover.vue`) |
| `og-image.png` | `og:image` / `twitter:image` — `seoMeta:` headmatter of all three root decks |
| `logo.png`, `workshop-logo.png`, `social-preview.png` | Staged spares (hi-res logo, README/social alternates) — kept for future use |

Root-absolute `/branding/…` paths are resolved against each deck's build base (`/`, `/3day/`,
`/templates/`, and the Pages sub-path) by Slidev / the theme's `resolveAsset` helper.
