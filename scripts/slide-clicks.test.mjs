/**
 * Frontmatter `clicks:` must not be lower than what the slide actually reveals.
 *
 * WHY THIS GATE EXISTS
 * Slidev treats a slide's frontmatter `clicks` as a HARD total override, not a
 * hint: `createClicksContextBase(..., clicksTotalOverrides)` returns it verbatim
 * from `get total()` (`@slidev/client/composables/useClicks.ts:155-161`), fed by
 * `route.meta.clicks` — which is `frontmatter.clicks`
 * (`@slidev/client/composables/useNav.ts:337-338`). Navigation clamps to that
 * total, so any element whose click index is above it is UNREACHABLE: it exists
 * in source, passes every other gate, and no learner ever sees it.
 *
 * WHAT THIS CHECK COVERS
 * For every slide in `pages/**\/index.md` that declares frontmatter `clicks`,
 * it walks the slide body in document order and models Slidev's click
 * accounting (`ClicksContext.calculateSince`, useClicks.ts:73-99):
 *   - `v-click` with no value        → relative, +1 (max = running offset)
 *   - `v-click="N"` (integer)        → absolute, max = N, offset unchanged
 *   - `v-clicks` on an element       → relative, +1 per child list item
 *   - `<CodeNote at="N">`            → this repo's component; it renders
 *                                      `<v-click :at="N">`, so absolute max = N
 *   - ```lang {a|b|c}```             → relative, +(steps - 1)
 *                                      (`CodeBlockWrapper.vue:72`)
 *   - ````md magic-move````          → relative, +(inner fences - 1)
 *                                      (`ShikiMagicMove.vue:96`)
 * HTML comments (including presenter notes) are stripped first: their contents
 * are never rendered as elements.
 *
 * WHAT THIS CHECK DOES *NOT* COVER — read before trusting a green
 *   - It only fires when frontmatter `clicks` is present. Without it the total
 *     is computed from the elements themselves and cannot truncate.
 *   - It does NOT flag `clicks` GREATER than the modelled maximum. That is a
 *     legitimate pattern here: `<TestPyramid :step="$clicks" />` (S12/S17/S18)
 *     consumes the total without registering any click of its own.
 *   - Registration order is approximated by DOCUMENT order. Slidev accumulates
 *     relative offsets in Vue mount order, which differs for nested click
 *     elements. No slide in `pages/**` nests them today.
 *   - It models click ACCOUNTING only. It does not render anything, so it says
 *     nothing about whether a reachable element is visible, on-canvas, or
 *     unclipped.
 *   - Click forms it cannot model statically are REJECTED, not ignored, so the
 *     gate can never silently under-count: see `UNSUPPORTED` below.
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'
import { collectPageIndexes, readPageSlides, splitSlides, stripHtmlComments } from './slide-source.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

/**
 * Click syntaxes this scanner refuses to guess at. Hitting one fails the test
 * with a request to extend the model rather than under-counting in silence.
 */
const UNSUPPORTED = [
  [/<\/?v-clicks?[\s/>]/, '<v-click> / <v-clicks> component form'],
  [/\bv-after\b/, 'v-after directive'],
  [/\bv-clicks?\.[\w-]+/, 'v-click / v-clicks modifier (e.g. .hide)'],
  [/\bv-switch\b/, 'v-switch directive'],
]

const RE_FENCE_OPEN = /^\s*(`{3,}|~{3,})(.*)$/
const RE_CLICK_ATTR = /\bv-(clicks?)\b(?:=(["'])(.*?)\2)?/g
const RE_CODE_NOTE = /<CodeNote\b[^>]*?\bat=(["'])([^"']*)\1/g

/** Count the reveal steps a fenced block contributes (relative delta). */
function fenceDelta(info, inner) {
  if (/\bmagic-move\b/.test(info)) {
    const steps = inner.filter((line) => RE_FENCE_OPEN.test(line)).length / 2
    return Math.max(0, Math.round(steps) - 1)
  }
  const spec = info.match(/\{([^}]*)\}/)
  if (!spec) return 0
  const parts = spec[1].split('|')
  return parts.length > 1 ? parts.length - 1 : 0
}

/** Count the list items a `v-clicks` element reveals, one click each. */
function clicksChildCount(lines, startIndex) {
  const tag = lines[startIndex].match(/<([\w-]+)[^>]*\bv-clicks\b/)
  const block = []
  if (tag) {
    const close = new RegExp(`</${tag[1]}>`)
    for (let i = startIndex; i < lines.length; i++) {
      block.push(lines[i])
      if (i > startIndex && close.test(lines[i])) break
    }
  } else {
    for (let i = startIndex + 1; i < lines.length; i++) {
      if (!lines[i].trim() && block.length) break
      block.push(lines[i])
    }
  }
  const html = (block.join('\n').match(/<li\b/g) ?? []).length
  if (html) return html
  const md = block.filter((line) => /^\s*(?:[-*+]|\d+\.)\s+\S/.test(line)).length
  return md
}

/**
 * Model the highest click index a slide body reaches.
 * Throws on any click syntax outside the covered set.
 */
export function requiredClicks(body, where = '<slide>') {
  const src = stripHtmlComments(body)
  for (const [re, what] of UNSUPPORTED) {
    if (re.test(src)) throw new Error(`${where}: unsupported click syntax (${what}) — extend scripts/slide-clicks.test.mjs`)
  }
  const lines = src.split('\n')
  let offset = 0
  let max = 0
  const relative_ = (delta) => {
    offset += delta
    max = Math.max(max, offset)
  }
  for (let i = 0; i < lines.length; i++) {
    const fence = lines[i].match(RE_FENCE_OPEN)
    if (fence) {
      const marker = fence[1]
      let end = lines.length
      for (let j = i + 1; j < lines.length; j++) {
        if (lines[j].startsWith(marker)) { end = j; break }
      }
      relative_(fenceDelta(fence[2].trim(), lines.slice(i + 1, end)))
      i = end
      continue
    }
    for (const m of lines[i].matchAll(RE_CODE_NOTE)) {
      if (!/^\d+$/.test(m[2])) throw new Error(`${where}: <CodeNote at="${m[2]}"> is not a plain integer — extend scripts/slide-clicks.test.mjs`)
      max = Math.max(max, Number(m[2]))
    }
    for (const m of lines[i].matchAll(RE_CLICK_ATTR)) {
      const plural = m[1] === 'clicks'
      const value = m[3]
      if (plural) {
        if (value !== undefined && value !== '') throw new Error(`${where}: v-clicks="${value}" is not modelled — extend scripts/slide-clicks.test.mjs`)
        const count = clicksChildCount(lines, i)
        if (!count) throw new Error(`${where}: v-clicks with no countable list items — extend scripts/slide-clicks.test.mjs`)
        relative_(count)
      } else if (value === undefined || value === '') {
        relative_(1)
      } else if (/^\d+$/.test(value)) {
        max = Math.max(max, Number(value))
      } else {
        throw new Error(`${where}: v-click="${value}" is not a plain integer — extend scripts/slide-clicks.test.mjs`)
      }
    }
  }
  return max
}

describe('slide source parser (shared with the slot gate)', () => {
  it('splits frontmatter from body and ignores --- inside fences and comments', () => {
    const slides = splitSlides(
      [
        '---', 'layout: cover', '---', '', '# One', '', '```md', '---', 'not: a slide', '---', '```', '',
        '---', '', '# Two', '', '<!--', '---', 'still note', '-->', '',
        '---', 'clicks: 2', '---', '', '# Three',
      ].join('\n'),
    )
    assert.equal(slides.length, 3)
    assert.deepEqual(slides[0].frontmatter, { layout: 'cover' })
    assert.deepEqual(slides[1].frontmatter, {})
    assert.deepEqual(slides[2].frontmatter, { clicks: 2 })
    assert.match(slides[0].body, /not: a slide/)
    assert.match(slides[1].body, /still note/)
  })

  it('parses every real page deck without a YAML error and finds each layout', () => {
    for (const { abs, slides } of readPageSlides(root)) {
      const rel = relative(root, abs)
      assert.ok(slides.length > 0, `${rel}: no slides parsed`)
      const declared = (readFileSync(abs, 'utf8').match(/^layout:\s*\S+/gm) ?? []).length
      const parsed = slides.filter((s) => s.frontmatter.layout).length
      assert.equal(parsed, declared, `${rel}: ${declared} layout: lines but ${parsed} parsed slides carry one`)
    }
  })

  it('finds page sources at all', () => {
    assert.ok(collectPageIndexes(join(root, 'pages')).length > 0)
  })
})

describe('click accounting model', () => {
  it('counts bare v-click relatively', () => {
    assert.equal(requiredClicks('<p v-click>a</p>\n<p v-click>b</p>'), 2)
  })

  it('takes the maximum of absolute v-click indexes without moving the cursor', () => {
    assert.equal(requiredClicks('<p v-click="1">a</p>\n<p v-click="6">b</p>\n<p v-click="6">c</p>'), 6)
  })

  it('counts <CodeNote at="N"> as an absolute click', () => {
    assert.equal(requiredClicks('<CodeNote at="4" label="x">y</CodeNote>'), 4)
  })

  it('counts fenced highlight steps as steps - 1', () => {
    assert.equal(requiredClicks('```hcl {none|1-2|all}\na\nb\n```'), 2)
    assert.equal(requiredClicks('```hcl {1,3-5}\na\n```'), 0)
  })

  it('counts magic-move blocks as blocks - 1', () => {
    assert.equal(requiredClicks('````md magic-move\n```hcl\na\n```\n```hcl\nb\n```\n```hcl\nc\n```\n````'), 2)
  })

  it('counts v-clicks list children, HTML and markdown alike', () => {
    assert.equal(requiredClicks('<ul v-clicks>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ul>'), 3)
    assert.equal(requiredClicks('<div v-clicks>\n\n- a\n- b\n\n</div>'), 2)
  })

  it('ignores click directives written inside HTML comments', () => {
    assert.equal(requiredClicks('<!--\n<p v-click>ghost</p>\n-->\n<p v-click>real</p>'), 1)
  })

  it('refuses click syntaxes it cannot model rather than under-counting', () => {
    assert.throws(() => requiredClicks('<v-clicks>\n\n- a\n\n</v-clicks>'), /unsupported click syntax/)
    assert.throws(() => requiredClicks('<p v-after>a</p>'), /unsupported click syntax/)
    assert.throws(() => requiredClicks('<p v-click.hide>a</p>'), /unsupported click syntax/)
    assert.throws(() => requiredClicks("<p v-click=\"'+2'\">a</p>"), /not a plain integer/)
  })
})

describe('no slide declares fewer clicks than it reveals', () => {
  it('every pages/**/index.md slide with frontmatter clicks can reach its last element', () => {
    const truncated = []
    for (const { abs, slides } of readPageSlides(root)) {
      const rel = relative(root, abs)
      for (const slide of slides) {
        assert.equal(
          slide.frontmatter.clicksStart,
          undefined,
          `${rel}:${slide.startLine} uses clicksStart, which shifts the reachable window — extend scripts/slide-clicks.test.mjs`,
        )
        const declared = slide.frontmatter.clicks
        if (declared === undefined) continue
        const where = `${rel}:${slide.startLine}`
        const needed = requiredClicks(slide.body, where)
        if (needed > declared) truncated.push(`${where}: frontmatter clicks: ${declared} but the slide reveals up to click ${needed}`)
      }
    }
    assert.deepEqual(
      truncated,
      [],
      truncated.length
        ? `frontmatter clicks is a hard total override, so these trailing elements never render:\n${truncated.join('\n')}`
        : undefined,
    )
  })
})
