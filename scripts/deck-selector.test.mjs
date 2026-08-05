import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync, rmSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, it } from 'node:test'

import { parseSelection, resolveSelection, selectSections } from './deck-selector.mjs'

const section = (id, overrides = {}) => ({
  id,
  slug: `topic-${id.toLowerCase()}`,
  title: `Topic ${id}`,
  tier: 'core',
  day: 1,
  canonical: true,
  status: 'authored',
  slidesMinutes: 10,
  labMinutes: 10,
  ...overrides,
})

describe('deck selection', () => {
  const sections = [
    section('S00', { day: 1 }),
    section('S01', { day: 1, canonical: false }),
    section('S02', { day: 2 }),
    section('S03', { day: 3 }),
  ]

  it('rejects invalid day selectors', () => {
    assert.throws(() => parseSelection(['--day', '4']), /invalid day/i)
    assert.throws(() => parseSelection(['--day', 'today']), /invalid day/i)
  })

  it('accepts pnpm argument separators without changing the selection', () => {
    assert.deepEqual(
      parseSelection(['--', '--day', '2']),
      { type: 'day', value: '2', action: 'dev', list: false, dryRun: false, help: false },
    )
  })

  it('records --dry-run without launching Slidev', () => {
    assert.deepEqual(
      parseSelection(['--section', 'S02', '--dry-run']),
      { type: 'section', value: 'S02', action: 'dev', list: false, dryRun: true, help: false },
    )
  })

  it('rejects reversed, unknown, and malformed contiguous ranges', () => {
    for (const range of ['S03-S01', 'S00-S99', 'S00,S02']) {
      const selection = parseSelection(['--range', range])
      assert.throws(() => selectSections(sections, selection), /invalid range/i)
    }
  })

  it('selects canonical sections for a day', () => {
    const selection = parseSelection(['--day', '1'])
    assert.deepEqual(
      selectSections(sections, selection).map((item) => item.id),
      ['S00'],
    )
  })

  it('selects optional appendix sections', () => {
    const selection = parseSelection(['--day', 'optional'])
    assert.deepEqual(
      selectSections(sections, selection).map((item) => item.id),
      ['S01'],
    )
  })

  it('selects a single section by id', () => {
    const selection = parseSelection(['--section', 's02'])
    assert.deepEqual(
      selectSections(sections, selection).map((item) => item.id),
      ['S02'],
    )
  })

  it('selects a contiguous manifest-order range', () => {
    const selection = parseSelection(['--range', 'S00-S02'])
    assert.deepEqual(
      selectSections(sections, selection).map((item) => item.id),
      ['S00', 'S01', 'S02'],
    )
  })

  it('never chooses the superset for a noninteractive invocation', () => {
    assert.throws(
      () => resolveSelection([], { isTTY: false, hasGum: false }),
      /choose.*--day.*--section.*--range/i,
    )
  })

  it('refuses when TTY is present but gum is missing', () => {
    assert.throws(
      () => resolveSelection([], { isTTY: true, hasGum: false }),
      /choose.*--day.*--section.*--range/i,
    )
  })
})

describe('deck launcher', () => {
  const repoRoot = resolve(import.meta.dirname, '..')
  const selectionPath = resolve(repoRoot, '.deck-selection.md')

  it('writes .deck-selection.md on --dry-run without launching Slidev', () => {
    rmSync(selectionPath, { force: true })
    const result = spawnSync(process.execPath, ['scripts/deck.mjs', '--section', 'S05', '--dry-run'], {
      cwd: repoRoot,
      encoding: 'utf8',
    })
    assert.equal(result.status, 0, result.stderr)
    assert.ok(existsSync(selectionPath))
    assert.match(readFileSync(selectionPath, 'utf8'), /S05 · State encryption/)
    rmSync(selectionPath, { force: true })
  })
})
