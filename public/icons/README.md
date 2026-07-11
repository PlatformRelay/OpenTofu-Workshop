# Icons & artwork

## HCL block glyphs — `blocks/{labeled,unlabeled}/*.svg`

Custom badge set for this workshop (one per HCL / OpenTofu / Terramate construct:
`resource`, `variable`, `output`, `module`, `provider`, `data`, `locals`,
`backend`, `state`, `encryption`, `test`, `mock`, `check`, `validation`, `import`,
`moved`, `removed`, `stack`, `generate`, `globals`). Original work, released under
the repository licence. Loaded by `theme/components/IacIcon.vue` as `kind="…"`.

## Brand / tool marks — `*.svg`

`opentofu-icon-*.svg` and the horizontal wordmark are **simplified, geometric
placeholders** created for this deck — they are *not* the official OpenTofu logo.
Before any public release, replace them with the official marks (respecting the
OpenTofu / Terraform / LocalStack trademark and brand guidelines) or keep these
neutral geometric stand-ins. Product names and logos belong to their respective
owners; nothing here implies endorsement.

## Adding an icon

1. Drop the SVG in the right folder (`blocks/labeled/`, `blocks/unlabeled/`, or the
   `icons/` root for a logo).
2. Add the slug to the `IacKind` union (block glyph) or the `name` union
   (logo) in `theme/components/IacIcon.vue`.
3. Reference it: `<IacIcon kind="resource" />` or `<IacIcon name="opentofu-icon-color" />`.
