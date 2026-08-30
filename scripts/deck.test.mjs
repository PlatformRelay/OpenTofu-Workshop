import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { describe, it } from 'node:test'

import {
  canonicalDayTotals,
  findGeneratedDrift,
  renderDeck,
  sections as workshopSections,
  validateDeckTierTruth,
  validateManifest,
  validatePlanningLanguage,
  validateRunbookFitPlan,
  validateRunbookTimings,
  validateSectionFrontmatter,
  validateSyllabusCatalog,
  validateSyllabusTimings,
} from './deck-manifest.mjs'

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

describe('deck manifest validation', () => {
  it('rejects a manifest whose source section is missing', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-deck-'))
    assert.throws(
      () => validateManifest([section('S00')], { repoRoot: root }),
      /missing section source.*S00/i,
    )
  })

  it('reports generated deck drift instead of silently overwriting it', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-deck-'))
    writeFileSync(join(root, 'slides-day-1.md'), 'stale\n')

    assert.deepEqual(
      findGeneratedDrift(new Map([
        ['slides-day-1.md', 'fresh\n'],
        ['slides-day-2.md', 'new\n'],
      ]), { repoRoot: root }),
      ['slides-day-1.md', 'slides-day-2.md'],
    )
  })

  it('rejects contradictory section day and tier frontmatter', () => {
    assert.throws(
      () => validateSectionFrontmatter(
        section('S03', { day: 1, tier: 'core' }),
        `---\nday: Day 2\nsection: '03'\ntier: optional\n---\n`,
      ),
      /S03.*day.*tier/i,
    )
  })

  it('rejects syllabus catalog drift from the manifest', () => {
    const manifest = [section('S11', { tier: 'optional', day: 1 })]
    const catalog = `
| ID | Section | Tier | Day | Status | 3-day cut |
| --- | --- | --- | --- | --- | --- |
| S11 | TACO landscape | core | 1 | authored | Skip |
`
    assert.throws(
      () => validateSyllabusCatalog(manifest, catalog),
      /S11.*tier.*optional/i,
    )
  })

  it('rejects per-section timing drift from the manifest', () => {
    const manifest = [section('S12', { day: 2, slidesMinutes: 20, labMinutes: 20 })]
    const timings = `
| ID | Section | Slides | Lab |
| --- | --- | ---: | ---: |
| S12 | Testing pyramid | 21 | 20 |
`
    assert.throws(
      () => validateSyllabusTimings(manifest, timings),
      /S12.*slides.*20/i,
    )
  })

  it('derives canonical totals and rejects planning drift', () => {
    const manifest = [
      section('S00', { canonical: true, day: 1, slidesMinutes: 40, labMinutes: 20 }),
      section('S01', { canonical: true, day: 1, slidesMinutes: 40, labMinutes: 20 }),
    ]
    assert.deepEqual(canonicalDayTotals(manifest).get(1), {
      slides: 80,
      lab: 40,
      total: 120,
    })
    assert.doesNotThrow(
      () => validatePlanningLanguage('Day 1: 120 minutes planned.', manifest),
    )
    assert.throws(
      () => validatePlanningLanguage('Day 1: 121 minutes planned.', manifest),
      /Day 1.*121.*expected.*120/i,
    )
  })

  it('binds the published fit-plan chain to the computed day-1 totals', () => {
    const manifest = [
      section('S00', { canonical: true, day: 1, slidesMinutes: 40, compressedSlides: 25 }),
      section('S01', { canonical: true, day: 1, slidesMinutes: 40, compressedSlides: 30 }),
    ]
    // superset 80, fit 55.
    assert.doesNotThrow(
      () => validatePlanningLanguage('Chain: **80 → 65**, then **65 → 55**.', manifest),
    )
    assert.throws(
      () => validatePlanningLanguage('Chain: **70 → 65**, then **65 → 55**.', manifest),
      /chain starts at 70; expected 80/i,
    )
    assert.throws(
      () => validatePlanningLanguage('Chain: **80 → 65**, then **65 → 50**.', manifest),
      /chain ends at 50; expected 55/i,
    )
    // A document with no published chain is not gated by this rule.
    assert.doesNotThrow(() => validatePlanningLanguage('No chain here.', manifest))
  })

  it('requires the runbook to publish the fit-plan chain and day totals', () => {
    const manifest = [
      section('S00', { canonical: true, day: 1, slidesMinutes: 40, labMinutes: 20, compressedSlides: 25 }),
      section('S01', { canonical: true, day: 1, slidesMinutes: 40, labMinutes: 20, compressedSlides: 30 }),
    ]
    // superset 80, fit 55; canonical day totals: day 1 = 80 + 40 = 120.
    const runbook = `
The arithmetic is explicit: **80 → 65**, then **65 → 55**.

| Day | Slides | Labs | Slides+labs (planned) | Against the budget |
| --- | ---: | ---: | ---: | --- |
| 1 | 80 | 40 | **120** | over |
| 2 | 0 | 0 | 0 | — |
| 3 | 0 | 0 | 0 | — |
`
    assert.doesNotThrow(() => validateRunbookFitPlan(runbook, manifest))
    // Absence is a failure, not a pass — unlike the README chain guard.
    assert.throws(
      () => validateRunbookFitPlan('No chain here.', manifest),
      /must publish the Day 1 fit-plan/i,
    )
    assert.throws(
      () => validateRunbookFitPlan(runbook.replace('**80 → 65**', '**70 → 65**'), manifest),
      /chain starts at 70; expected 80/i,
    )
    assert.throws(
      () => validateRunbookFitPlan(runbook.replace('**65 → 55**', '**65 → 50**'), manifest),
      /chain ends at 50; expected 55/i,
    )
    assert.throws(
      () => validateRunbookFitPlan(runbook.replace('**120**', '**121**'), manifest),
      /Day 1 totals row claims 80\+40=121; expected 80\+40=120/i,
    )
    assert.throws(
      () => validateRunbookFitPlan(runbook.replace('| 3 | 0 | 0 | 0 | — |', ''), manifest),
      /day-totals table for days 1-3/i,
    )
  })

  it('validates deck tier truth with verify.sh-compatible errors', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-deck-'))
    writeFileSync(join(root, 'slides.md'), `---
# S05 · State encryption · recommended · Day 1
src: ./pages/S05-state-encryption/index.md
hide: false
---
`)
    writeFileSync(join(root, 'slides-3day.md'), `---
# S05 · State encryption · core · Day 1
src: ./pages/S05-state-encryption/index.md
hide: false
---
---
# S18 · Integration · optional · Day 2
src: ./pages/S18-integration-cost/index.md
hide: false
---
`)
    assert.throws(
      () => validateDeckTierTruth(workshopSections, { repoRoot: root }),
      /tier drift: S05 is 'recommended' in slides\.md but 'core' in slides-3day\.md/,
    )

    writeFileSync(join(root, 'slides.md'), `---
# S05 · State encryption · core · Day 1
src: ./pages/S05-state-encryption/index.md
hide: false
---
`)
    assert.throws(
      () => validateDeckTierTruth(workshopSections, { repoRoot: root }),
      /hide invariant: S18 is 'optional' but hide='false' in slides-3day\.md/,
    )
  })

  it('renders a generated deck header marker', () => {
    const markdown = renderDeck([section('S00')], {
      title: 'Day 1',
      description: 'Author foundations',
      deck: 'day',
    })
    assert.match(markdown, /Generated by scripts\/generate-decks\.mjs/)
    assert.match(markdown, /# S00 · Topic S00 · core · Day 1/)
  })

  it('validates the live manifest against shipped section sources', () => {
    const root = resolve(import.meta.dirname, '..')
    assert.doesNotThrow(() => validateManifest(workshopSections, { repoRoot: root }))
  })

  it('validates runbook timing tables against the manifest', () => {
    const root = resolve(import.meta.dirname, '..')
    const runbook = readFileSync(join(root, 'docs/facilitator-runbook.md'), 'utf8')
    assert.doesNotThrow(() => validateRunbookTimings(workshopSections, runbook))
    assert.doesNotThrow(() => validateRunbookFitPlan(runbook, workshopSections))
  })
})

describe('deck CI contract', () => {
  it('wires deck generation checks into CI', () => {
    const workflow = readFileSync(
      join(import.meta.dirname, '..', '.github', 'workflows', 'ci.yml'),
      'utf8',
    )
    for (const command of [
      'pnpm run decks:check',
      'pnpm run test:deck',
      'pnpm run build:day1',
      'pnpm run build:day2',
      'pnpm run build:day3',
    ]) {
      assert.match(workflow, new RegExp(command.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    }
  })
})
