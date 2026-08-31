#!/usr/bin/env node
// Front-door honesty: live deck discovery on README + docs landing.
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'

import { dayOneFitTotal, dayOneSupersetSlidesTotal } from './deck-manifest.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const PAGES = 'https://platformrelay.github.io/OpenTofu-Workshop'

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

test('README links live superset, 3-day, and template decks on Pages', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  for (const rel of ['deck/', 'deck/3day/', 'deck/templates/']) {
    assert.match(
      readme,
      new RegExp(`${escapeRegExp(PAGES)}/${escapeRegExp(rel)}`),
      `README must link the live ${rel} deck`,
    )
  }
})

test('docs landing links live decks on Pages', () => {
  const index = readFileSync(resolve(ROOT, 'docs/index.md'), 'utf8')
  for (const rel of ['deck/', 'deck/3day/', 'deck/templates/']) {
    assert.match(
      index,
      new RegExp(`${escapeRegExp(PAGES)}/${escapeRegExp(rel)}`),
      `docs/index.md must link the live ${rel} deck`,
    )
  }
})

// US-O-README-SLIM: the README is a front door — the fit-plan and day-total
// tables live in docs/facilitator-runbook.md, and the README routes to them.
// The digits themselves are machine-checked by validateRunbookFitPlan() in
// scripts/deck-manifest.mjs; this test pins the LOCATION so the tables cannot
// silently migrate back and re-bloat the front door.
test('README routes timing tables to the runbook instead of hosting them', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  const runbook = readFileSync(resolve(ROOT, 'docs/facilitator-runbook.md'), 'utf8')
  assert.doesNotMatch(
    readme,
    /### Day 1 fit plan|### Published day totals|Running total/,
    'README must not host the fit-plan or day-total tables (they live in the runbook)',
  )
  assert.match(
    readme,
    /\]\(docs\/facilitator-runbook\.md#day-1-fit-plan\)/,
    'README must link the runbook Day 1 fit plan',
  )
  assert.match(
    readme,
    /\]\(docs\/facilitator-runbook\.md#live-cut-order\)/,
    'README must link the runbook day totals (live cut-order)',
  )
  assert.match(readme, /## Scope and timing \(known issue\)/, 'README keeps the scope-and-timing anchor')
  assert.match(runbook, /### Day 1 fit plan/, 'runbook must host the Day 1 fit plan')
  assert.match(runbook, /\| Order \| Action \| Minutes \| Running total \|/, 'runbook must host the fit-plan table')
})

test('README pitches running the workshop for your team', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  assert.match(
    readme,
    /## Run this workshop for your team/,
    'README must carry the adoption pitch section',
  )
  const pitch = readme.split('## Run this workshop for your team')[1].split('\n## ')[0]
  assert.match(pitch, /\*\*What you get:\*\*/, 'pitch must say what an adopter gets')
  assert.match(pitch, /\*\*How to deliver it:\*\*/, 'pitch must say how to deliver')
  assert.match(pitch, /\*\*Fork and customize:\*\*/, 'pitch must point at forking/customizing')
  assert.match(
    pitch,
    /\]\(docs\/facilitator-runbook\.md\)/,
    'pitch must route adopters to the facilitator runbook',
  )
})

// US-O-LINKS404 fold-in: the README's "compresses Day-1 slide time from 705
// minutes to 400" literals became unbound when US-O-README-SLIM moved the
// arithmetic-chain guard to the runbook ("Day-1" with a hyphen also dodges
// validatePlanningLanguage's day-minute regex). Bind BOTH literals to the
// manifest so the sentence cannot silently rot when timings change.
test('README fit-plan compression literals equal the manifest totals', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  const match = readme.match(
    /compresses Day-1 \*\*slide\*\* time from (\d+) minutes to (\d+)/,
  )
  assert.ok(match, 'README must state the Day-1 slide-time compression')
  assert.equal(
    Number(match[1]),
    dayOneSupersetSlidesTotal(),
    'README compression start must equal the manifest Day-1 superset slides total',
  )
  assert.equal(
    Number(match[2]),
    dayOneFitTotal(),
    'README compression target must equal the manifest Day-1 fit-plan total',
  )
})

// US-O-ROADMAP: the project direction is public, not buried in gitignored
// planning docs — the front door must route contributors to ROADMAP.md.
test('README links the public roadmap', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  assert.match(readme, /\]\(ROADMAP\.md\)/, 'README must link ROADMAP.md')
})

test('README contributing section names the small-fix fast path', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  assert.match(readme, /\]\(CONTRIBUTING\.md\)/, 'README must link CONTRIBUTING.md')
  assert.match(
    readme,
    /fast path/i,
    'README must mention the CONTRIBUTING small-fix fast path (FASTPATH-F2)',
  )
})

// DOC-4: the section library is S00–S28 (syllabus, slides.md); the README and
// beta-limitations used to undersell it as S00–S26.
for (const file of ['README.md', 'docs/beta-limitations.md']) {
  test(`${file} claims the full S00\u2013S28 library, never S00\u2013S26`, () => {
    const content = readFileSync(resolve(ROOT, file), 'utf8')
    assert.doesNotMatch(
      content,
      /S00`?[\u2013-]`?S26/,
      `${file} must not undersell the section library as S00\u2013S26`,
    )
    assert.match(content, /S00`?[\u2013-]`?S28/, `${file} must claim the S00\u2013S28 library`)
  })
}

test('README has no controlled-beta warning', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  assert.doesNotMatch(
    readme,
    /Controlled beta/i,
    'README must not ship a controlled-beta warning after stable release',
  )
})

test('docs landing has no controlled-beta admonition', () => {
  const index = readFileSync(resolve(ROOT, 'docs/index.md'), 'utf8')
  assert.doesNotMatch(index, /Controlled beta/i)
  assert.doesNotMatch(index, /!!!\s*warning\s*"Controlled beta"/)
})

test('LICENSE is 0BSD (no attribution required)', () => {
  const license = readFileSync(resolve(ROOT, 'LICENSE'), 'utf8')
  assert.match(license, /BSD Zero Clause License|0BSD/i)
  assert.doesNotMatch(
    license,
    /The above copyright notice and this permission notice shall be included/,
  )
})

test('README describes 0BSD without MIT attribution requirement', () => {
  const readme = readFileSync(resolve(ROOT, 'README.md'), 'utf8')
  assert.match(readme, /0BSD/)
  assert.doesNotMatch(readme, /Keep the copyright notice with substantial copies/)
  assert.doesNotMatch(readme, /\[MIT License\]|\*\*\[MIT\]|License: MIT/)
})

// US-P-BADGE — kubernetes-workshop-style status badge row for workflows that
// actually exist: CI, Pages, Documentation, Release, License (0BSD) — in that
// order, identical on README and the docs landing. No CodeQL badge until
// US-P-CODEQL ships a codeql.yml (a 404 badge is a defect).
const REPO = 'https://github.com/PlatformRelay/OpenTofu-Workshop'
const BADGES = [
  {
    alt: 'CI',
    image: `${REPO}/actions/workflows/ci.yml/badge.svg`,
    link: `${REPO}/actions/workflows/ci.yml`,
  },
  {
    alt: 'Pages',
    image: `${REPO}/actions/workflows/pages.yml/badge.svg`,
    link: `${REPO}/actions/workflows/pages.yml`,
  },
  {
    alt: 'Documentation',
    image:
      'https://img.shields.io/badge/documentation-GitHub%20Pages-2ea44f?logo=readthedocs&logoColor=white',
    link: `${PAGES}/`,
  },
  {
    alt: 'Release',
    image: 'https://img.shields.io/github/v/release/PlatformRelay/OpenTofu-Workshop',
    link: `${REPO}/releases`,
  },
  {
    alt: 'License: 0BSD',
    image: 'https://img.shields.io/github/license/PlatformRelay/OpenTofu-Workshop',
    link: `${REPO}/blob/main/LICENSE`,
  },
]

function badgeMarkdown({ alt, image, link }) {
  return `[![${alt}](${image})](${link})`
}

for (const [label, file] of [
  ['README', 'README.md'],
  ['docs landing', 'docs/index.md'],
]) {
  test(`${label} shows CI/Pages/Documentation/Release/License badges in order`, () => {
    const content = readFileSync(resolve(ROOT, file), 'utf8')
    let cursor = -1
    for (const badge of BADGES) {
      const markdown = badgeMarkdown(badge)
      const at = content.indexOf(markdown)
      assert.ok(at !== -1, `${file} must contain the ${badge.alt} badge: ${markdown}`)
      assert.ok(at > cursor, `${file} badge out of order: ${badge.alt} must follow the previous badge`)
      cursor = at
    }
  })

  test(`${label} license badge says 0BSD, never MIT`, () => {
    const content = readFileSync(resolve(ROOT, file), 'utf8')
    assert.match(content, /\[!\[License: 0BSD\]/, `${file} license badge alt text must say 0BSD`)
    assert.doesNotMatch(content, /License: MIT/, `${file} must not claim an MIT license`)
  })

  test(`${label} has no CodeQL badge (US-P-CODEQL not shipped)`, () => {
    const content = readFileSync(resolve(ROOT, file), 'utf8')
    assert.doesNotMatch(
      content,
      /codeql|CodeQL/,
      `${file} must not show a CodeQL badge until .github/workflows/codeql.yml exists`,
    )
  })
}
