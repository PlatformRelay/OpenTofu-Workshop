/**
 * Every raster image under `public/covers/` must stay within the per-file byte
 * budget, and every `image:` frontmatter reference on a `pages/**` slide must
 * resolve to a file that actually exists under `public/`.
 *
 * WHY THIS GATE EXISTS
 * US-O-COVERS recompressed 27 ~2.6MB section-cover PNGs to ~250KB WebPs
 * (69MB → 6.6MB working tree). Nothing else stops a future cover from landing
 * as a multi-megabyte PNG again: `pnpm lint` never stats `public/`, the deck
 * builds happily embed any size, and a broken `image:` path renders as a
 * black/blank cover in PDF/PNG export while every text-level gate stays green.
 *
 * WHAT THIS CHECK COVERS
 *   - an INVENTORY of `public/covers/` (every file, not a count): each raster
 *     image (webp/png/jpg/jpeg/gif/avif) at most BUDGET_BYTES; SVGs get the
 *     same budget since a multi-MB "vector" is just as much repo weight
 *   - every `image:` line in `pages/**` frontmatter that points into the
 *     public dir (leading `/`): the target file must exist under `public/`
 *
 * WHAT THIS CHECK DOES *NOT* COVER
 *   - visual quality of the compression (a 1-byte black webp would pass)
 *   - images outside `public/covers/` (branding, icons keep their own sizes)
 *   - non-frontmatter image references (inline markdown/HTML on slides)
 */
import assert from 'node:assert/strict'
import { existsSync, readdirSync, statSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'
import { readPageSlides } from './slide-source.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const coversDir = join(root, 'public/covers')

/** Per-file byte budget for cover imagery (AC US-O-COVERS: flag >500KB). */
export const BUDGET_BYTES = 500 * 1024

/** Pure core, unit-testable: returns the over-budget entries of an inventory. */
export function overBudget(inventory, budgetBytes) {
  return inventory
    .filter(({ bytes }) => bytes > budgetBytes)
    .map(({ name, bytes }) => `${name} (${bytes} bytes > ${budgetBytes})`)
}

describe('covers byte budget (US-O-COVERS)', () => {
  it('flags over-budget entries and passes under-budget ones (both polarities)', () => {
    const inventory = [
      { name: 'ok.webp', bytes: BUDGET_BYTES },
      { name: 'fat.png', bytes: BUDGET_BYTES + 1 },
    ]
    assert.deepEqual(overBudget(inventory, BUDGET_BYTES), [
      `fat.png (${BUDGET_BYTES + 1} bytes > ${BUDGET_BYTES})`,
    ])
    assert.deepEqual(overBudget([{ name: 'ok.webp', bytes: 1 }], BUDGET_BYTES), [])
  })

  it('every file in public/covers/ is within the per-file budget', () => {
    const names = readdirSync(coversDir).filter((n) => !n.startsWith('.'))
    assert.ok(names.length > 0, 'public/covers/ inventory is empty — check the path')
    const inventory = names.map((name) => ({
      name,
      bytes: statSync(join(coversDir, name)).size,
    }))
    assert.deepEqual(
      overBudget(inventory, BUDGET_BYTES),
      [],
      'over-budget cover imagery — recompress (WebP q85 kept the set ~250KB/file)',
    )
  })

  it('every pages/** frontmatter image resolves to a file under public/', () => {
    const missing = []
    let seen = 0
    for (const { abs, slides } of readPageSlides(root)) {
      for (const slide of slides) {
        const image = slide.frontmatter?.image
        if (typeof image !== 'string' || !image.startsWith('/')) continue
        seen += 1
        if (!existsSync(join(root, 'public', image.slice(1)))) {
          missing.push(`${relative(root, abs)} -> ${image}`)
        }
      }
    }
    assert.ok(seen > 0, 'no frontmatter image references found — matcher rotted')
    assert.deepEqual(missing, [], 'frontmatter image paths that do not exist under public/ (blank-cover export failure mode)')
  })
})
