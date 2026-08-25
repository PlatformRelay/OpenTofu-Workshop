/**
 * Every `::slot::` marker in `pages/**\/index.md` must name a slot its layout
 * actually declares.
 *
 * WHY THIS GATE EXISTS
 * Slidev compiles `::name::` into `<template #name>` on the layout component.
 * Vue silently discards a scoped slot the component never renders, so a layout
 * missing `<slot name="name" />` drops that whole block: the content exists in
 * source, `pnpm lint` never reads `pages/**`, `link-check` never reads
 * `pages/**`, and `test:pages` asserts term presence rather than display — so
 * every gate stays green while learners see nothing. Three layouts shipped that
 * way before this check existed (`comparison`/`two-cols-code` had no `left`,
 * `code-walkthrough` had no `notes`).
 *
 * WHAT THIS CHECK COVERS
 *   - the slot names declared by each `theme/layouts/*.vue`, read from
 *     `<slot />` / `<slot name="…" />` in the template (HTML comments stripped)
 *   - every `::name::` marker on a `pages/**` slide, matched against the slot
 *     names of that slide's `layout:` (or the default layout when absent)
 *   - layouts this repo does not define: those cannot be introspected here, so
 *     a slot marker under one is failed rather than skipped
 *
 * WHAT THIS CHECK DOES *NOT* COVER
 *   - it does not render anything, so it cannot tell whether a slot that IS
 *     declared is positioned, sized, or styled usefully
 *   - it does not check the default (unnamed) slot, which every layout has
 *   - it does not validate layout props (`leftHeading`, `lab`, …)
 */
import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { basename, dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'
import { readPageSlides, stripHtmlComments } from './slide-source.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const layoutsDir = join(root, 'theme/layouts')

/** Slot names each `theme/layouts/*.vue` declares. Default slot is `''`. */
function readLayoutSlots() {
  const map = new Map()
  for (const file of readdirSync(layoutsDir)) {
    if (!file.endsWith('.vue')) continue
    const src = stripHtmlComments(readFileSync(join(layoutsDir, file), 'utf8'))
    const names = new Set()
    for (const m of src.matchAll(/<slot\b([^>]*)>/g)) {
      const named = m[1].match(/\bname="([^"]+)"/)
      names.add(named ? named[1] : '')
    }
    map.set(basename(file, '.vue'), names)
  }
  return map
}

describe('theme layouts declare the slots the decks fill', () => {
  const layoutSlots = readLayoutSlots()

  it('reads slot names out of every theme layout', () => {
    assert.ok(layoutSlots.size > 0, 'expected theme/layouts/*.vue')
    for (const [name, slots] of layoutSlots) {
      assert.ok(slots.has(''), `${name}.vue declares no default slot`)
    }
  })

  it('no pages/**/index.md slide fills a slot its layout would discard', () => {
    const dropped = []
    for (const { abs, slides } of readPageSlides(root)) {
      const rel = relative(root, abs)
      for (const slide of slides) {
        const body = stripHtmlComments(slide.body)
        const markers = [...body.matchAll(/^::([\w-]+)::\s*$/gm)].map((m) => m[1])
        if (!markers.length) continue
        const layout = slide.frontmatter.layout ?? 'default'
        const slots = layoutSlots.get(layout)
        for (const marker of markers) {
          if (!slots) {
            dropped.push(`${rel}:${slide.startLine} uses ::${marker}:: under layout "${layout}", which is not defined in theme/layouts/ — its slots cannot be verified`)
          } else if (!slots.has(marker)) {
            dropped.push(`${rel}:${slide.startLine} fills ::${marker}:: but theme/layouts/${layout}.vue declares only [${[...slots].map((s) => s || '(default)').join(', ')}]`)
          }
        }
      }
    }
    assert.deepEqual(
      dropped,
      [],
      dropped.length
        ? `Vue discards a slot the layout never renders, so this content is invisible to every learner:\n${dropped.join('\n')}`
        : undefined,
    )
  })

  it('code-walkthrough slides with a ::notes:: rail keep their code inside the narrowed column', () => {
    // Filling ::notes:: turns code-walkthrough into code + rail, which costs the
    // code roughly a third of its width. The column overflows with `overflow:
    // auto`, so anything past the budget is clipped — invisible content again,
    // the very defect the notes slot was added to fix. Capacity at the layout's
    // --slidev-code-font-size measured ~91 columns off an exported frame, which
    // is worth roughly +/- 2 columns, so the budget sits below the bottom of
    // that interval. RAISING IT REQUIRES RE-MEASURING THE SAME WAY: export a
    // railed slide with `slidev export --with-clicks` (no --per-slide) and read
    // the real column width off the frame. Do not guess it upward.
    // Width only: nothing in this repo gates slide HEIGHT.
    const MAX_RAILED_CODE_COLUMNS = 88
    const wide = []
    for (const { abs, slides } of readPageSlides(root)) {
      const rel = relative(root, abs)
      for (const slide of slides) {
        if (slide.frontmatter.layout !== 'code-walkthrough') continue
        const body = stripHtmlComments(slide.body)
        if (!/^::notes::\s*$/m.test(body)) continue
        for (const fence of body.matchAll(/```[\w-]*[^\n]*\n([\s\S]*?)```/g)) {
          for (const [i, line] of fence[1].split('\n').entries()) {
            if (line.length > MAX_RAILED_CODE_COLUMNS) {
              wide.push(`${rel}:${slide.startLine} (fence line ${i + 1}) is ${line.length} columns: ${line}`)
            }
          }
        }
      }
    }
    assert.deepEqual(
      wide,
      [],
      wide.length
        ? `the ::notes:: rail narrows the code column; these lines would be clipped out of sight:\n${wide.join('\n')}`
        : undefined,
    )
  })

  it('two-column layouts move the slide intro to the header when ::left:: is used', () => {
    // With an explicit ::left:: the default slot holds the kicker + H1. Without
    // the guard those render inside the left panel instead of the header.
    for (const name of ['comparison', 'two-cols-code']) {
      const src = readFileSync(join(layoutsDir, `${name}.vue`), 'utf8')
      assert.match(src, /<slot\s+v-if="slots\.left"\s*\/>/, `${name}.vue must render the default slot in the header when a left slot is provided`)
      assert.match(src, /<slot\s+v-if="slots\.left"\s+name="left"\s*\/>/, `${name}.vue must render the left slot`)
      assert.match(src, /<slot\s+v-else\s*\/>/, `${name}.vue must keep rendering the default slot as the left column when no left slot is provided`)
    }
  })
})
