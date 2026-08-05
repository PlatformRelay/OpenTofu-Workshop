import assert from 'node:assert/strict'
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
