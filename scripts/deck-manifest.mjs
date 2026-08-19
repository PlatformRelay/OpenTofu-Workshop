import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

export const sectionTimings = {
  S00: [40, 20], S01: [50, 20], S02: [50, 20], S03: [60, 20], S04: [50, 20],
  S05: [60, 25], S06: [50, 25], S15: [50, 30], S07: [60, 35], S08: [65, 30],
  S09: [50, 30], S10: [45, 25], S11: [35, 20],
  S12: [20, 20], S13: [30, 30], S14: [35, 35], S16: [35, 35], S17: [30, 30],
  S18: [30, 30], S19: [30, 30],
  S20: [25, 25], S21: [30, 30], S22: [30, 30], S23: [30, 30], S24: [25, 25],
  S25: [25, 25], S26: [60, 60], S27: [20, 20], S28: [20, 20],
}

const sectionDefinitions = [
  {
    id: 'S00', slug: 'welcome', title: 'Welcome & setup', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 25,
    fitPlan: 'COMPRESS S00 40→25 (-15); preflight setup, retain orientation + first apply.',
  },
  {
    id: 'S01', slug: 'iac', title: 'Infrastructure as Code', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 30,
    fitPlan: 'COMPRESS S01 50→30 (-20); fork timeline pre-read, retain why IaC + design principles + alternatives + governance.',
  },
  {
    id: 'S02', slug: 'hcl-basics', title: 'HCL & building blocks', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 35,
    fitPlan: 'COMPRESS S02 50→35 (-15); fewer block variants, retain references + break/fix.',
  },
  {
    id: 'S03', slug: 'core-workflow', title: 'The core workflow', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 45,
    fitPlan: 'COMPRESS S03 60→45 (-15); one lifecycle run, retain plan reading + destroy.',
  },
  {
    id: 'S06', slug: 'variables', title: 'Variables, validation & types', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 35,
    fitPlan: 'COMPRESS S06 50→35 (-15); retain typed objects + validation, assign precedence.',
  },
  {
    id: 'S15', slug: 'validation-checks', title: 'Validation, preconditions & checks', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 35,
    fitPlan: 'COMPRESS S15 50→35 (-15); retain blocking condition + check, assign matrix.',
  },
  {
    id: 'S04', slug: 'state', title: 'State', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 35,
    fitPlan: 'COMPRESS S04 50→35 (-15); demo inspection, assign backend migration follow-up.',
  },
  {
    id: 'S05', slug: 'state-encryption', title: 'State encryption', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 45,
    fitPlan: 'COMPRESS S05 60→45 (-15); demo encryption, assign key rotation follow-up.',
  },
  {
    id: 'S07', slug: 'modules', title: 'Modules', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'compress', compressedSlides: 50,
    fitPlan: 'COMPRESS S07 60→50 (-10); retain local modules, demo registry/OCI lookup.',
  },
  {
    id: 'S08', slug: 'naming', title: 'Naming & labelling module', tier: 'core', day: 1, canonical: true,
    status: 'authored', fitAction: 'keep', compressedSlides: 65,
    fitPlan: 'KEEP S08 65 min; flagship synthesis and learner proof remain intact.',
  },
  {
    id: 'S09', slug: 'best-practices', title: 'Best practices', tier: 'recommended', day: 1, canonical: false,
    status: 'authored', fitAction: 'skip', fitPlan: 'SKIP S09 (-50) in delivery; recommended must remain hide:false.',
  },
  {
    id: 'S10', slug: 'opentofu-differentiators', title: 'OpenTofu differentiators', tier: 'recommended', day: 1, canonical: false,
    status: 'authored', fitAction: 'skip', fitPlan: 'SKIP S10 (-45) in delivery; recommended must remain hide:false.',
  },
  {
    id: 'S11', slug: 'taco-landscape', title: 'The TACO landscape', tier: 'optional', day: 1, canonical: false,
    status: 'authored', fitAction: 'skip', fitPlan: 'SKIP S11 (-35); optional and already hidden with hide:true.',
  },
  {
    id: 'S12', slug: 'testing-pyramid', title: 'Why test IaC + the testing pyramid', tier: 'core', day: 2, canonical: true,
    status: 'authored',
  },
  {
    id: 'S13', slug: 'static-analysis', title: 'Static analysis & formatting', tier: 'core', day: 2, canonical: true,
    status: 'authored',
  },
  {
    id: 'S14', slug: 'security-scanners', title: 'Security & policy scanners', tier: 'core', day: 2, canonical: true,
    status: 'authored',
  },
  {
    id: 'S16', slug: 'tofu-test', title: 'Native testing — tofu test', tier: 'core', day: 2, canonical: true,
    status: 'authored',
  },
  {
    id: 'S17', slug: 'mocking', title: 'Mocking providers', tier: 'core', day: 2, canonical: true,
    status: 'authored',
  },
  {
    id: 'S18', slug: 'integration-cost', title: 'Integration, e2e & cost', tier: 'optional', day: 2, canonical: false,
    status: 'authored',
  },
  {
    id: 'S19', slug: 'testing-cicd', title: 'Testing in CI/CD', tier: 'recommended', day: 2, canonical: true,
    status: 'authored',
  },
  {
    id: 'S20', slug: 'why-terramate', title: 'Why Terramate', tier: 'core', day: 3, canonical: true,
    status: 'authored',
  },
  {
    id: 'S21', slug: 'stacks', title: 'Stacks', tier: 'core', day: 3, canonical: true,
    status: 'authored',
  },
  {
    id: 'S22', slug: 'codegen', title: 'Code generation', tier: 'core', day: 3, canonical: true,
    status: 'authored',
  },
  {
    id: 'S23', slug: 'orchestration', title: 'Orchestration & ordering', tier: 'core', day: 3, canonical: true,
    status: 'authored',
  },
  {
    id: 'S24', slug: 'change-detection', title: 'Change detection & filtering', tier: 'recommended', day: 3, canonical: true,
    status: 'authored',
  },
  {
    id: 'S25', slug: 'terramate-ci', title: 'Terramate in CI + Cloud', tier: 'optional', day: 3, canonical: false,
    status: 'authored',
  },
  {
    id: 'S26', slug: 'capstone', title: 'Capstone & wrap-up', tier: 'core', day: 3, canonical: true,
    status: 'authored',
  },
  {
    id: 'S27', slug: 'terragrunt-comparison', title: 'Terragrunt vs Terramate', tier: 'optional', day: 3, canonical: false,
    status: 'authored',
  },
  {
    id: 'S28', slug: 'ecosystem-tooling', title: 'Ecosystem tooling', tier: 'optional', day: 3, canonical: false,
    status: 'authored',
  },
]

export const sections = sectionDefinitions.map((section) => {
  const [slidesMinutes, labMinutes] = sectionTimings[section.id] ?? []
  return { ...section, slidesMinutes, labMinutes }
})

const supersetFrontmatter = `---
theme: ./theme
title: OpenTofu Practitioner Workshop
info: |
  Open source, vendor-neutral OpenTofu workshop.
  Superset root deck: imports every section S00–S28. Toggle any section
  with \`hide: true\` on its import block below.
favicon: '/branding/favicon-32.png'
seoMeta:
  ogTitle: OpenTofu Practitioner Workshop
  ogDescription: >-
    Open source, vendor-neutral OpenTofu workshop — Infrastructure as Code done
    right: write it, test it, scale it. 3 days, 50% hands-on, LocalStack labs.
  ogImage: https://platformrelay.github.io/OpenTofu-Workshop/branding/og-image.png
  ogUrl: https://platformrelay.github.io/OpenTofu-Workshop/
  twitterCard: summary_large_image
  twitterImage: https://platformrelay.github.io/OpenTofu-Workshop/branding/og-image.png
layout: cover
meta: 3 days · 50% hands-on · OpenTofu-first · LocalStack labs
logo: /branding/logo-512.png
---`

const cutFrontmatter = `---
theme: ./theme
title: OpenTofu Practitioner Workshop — 3-day cut
info: |
  Canonical 3-day delivery cut. Same section library as slides.md; optional-tier
  and selected deep-dive sections are hidden here via \`hide: true\`.
favicon: '/branding/favicon-32.png'
seoMeta:
  ogTitle: OpenTofu Practitioner Workshop — 3-day cut
  ogDescription: >-
    The canonical 3-day delivery cut of the open source, vendor-neutral OpenTofu
    workshop — core and recommended sections, 50% hands-on.
  ogImage: https://platformrelay.github.io/OpenTofu-Workshop/branding/og-image.png
  ogUrl: https://platformrelay.github.io/OpenTofu-Workshop/3day/
  twitterCard: summary_large_image
  twitterImage: https://platformrelay.github.io/OpenTofu-Workshop/branding/og-image.png
layout: cover
meta: 3 days · core + recommended · OpenTofu-first
logo: /branding/logo-512.png
---`

export const generatedDecks = [
  {
    file: 'slides-day-1.md',
    title: 'Day 1',
    description: 'Author foundations — HCL, workflow, state, modules, naming',
    deck: 'day',
    select: (section) => section.day === 1 && section.canonical,
  },
  {
    file: 'slides-day-2.md',
    title: 'Day 2',
    description: 'Test IaC — pyramid, lint, scanners, tofu test, mocks, CI',
    deck: 'day',
    select: (section) => section.day === 2 && section.canonical,
  },
  {
    file: 'slides-day-3.md',
    title: 'Day 3',
    description: 'Scale with Terramate — stacks, codegen, orchestration, capstone',
    deck: 'day',
    select: (section) => section.day === 3 && section.canonical,
  },
  {
    file: 'slides-3day.md',
    title: '3-day cut',
    description: 'The canonical 3-day delivery cut with fit-plan markers',
    deck: 'cut',
    select: () => true,
  },
  {
    file: 'slides.md',
    title: 'Content superset',
    description: 'Every section S00–S28, each individually toggleable',
    deck: 'superset',
    select: () => true,
  },
]

export function sectionPath(section) {
  return `./pages/${section.id}-${section.slug}/index.md`
}

export function validateManifest(manifest = sections, { repoRoot = resolve(import.meta.dirname, '..') } = {}) {
  const seenIds = new Set()
  const seenPaths = new Set()
  for (const section of manifest) {
    if (seenIds.has(section.id))
      throw new Error(`Duplicate section ID ${section.id}`)
    seenIds.add(section.id)

    const source = sectionPath(section)
    if (seenPaths.has(source))
      throw new Error(`Duplicate section source ${source}`)
    seenPaths.add(source)

    if (!/^S\d{2}$/.test(section.id) || ![1, 2, 3].includes(section.day)
      || !['core', 'recommended', 'optional'].includes(section.tier)
      || !['authored', 'deferred'].includes(section.status)
      || !Number.isInteger(section.slidesMinutes) || section.slidesMinutes < 0
      || !Number.isInteger(section.labMinutes) || section.labMinutes < 0) {
      throw new Error(`Invalid manifest metadata for ${section.id}`)
    }
    if (!existsSync(resolve(repoRoot, source)))
      throw new Error(`Missing section source for ${section.id}: ${source}`)
  }

  const pagesRoot = resolve(repoRoot, 'pages')
  if (existsSync(pagesRoot)) {
    const authored = readdirSync(pagesRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && /^S\d{2}-/.test(entry.name))
      .map((entry) => entry.name.slice(0, 3))
    const omitted = authored.filter((id) => !seenIds.has(id))
    if (omitted.length)
      throw new Error(`Manifest is missing authored section(s): ${omitted.join(', ')}`)
  }
  return true
}

function frontmatterBlocks(markdown) {
  return markdown.split(/^---\s*$/m).map((block) => block.trim())
}

function scalar(block, key) {
  const match = block.match(new RegExp(`^${key}:\\s*(.*)$`, 'm'))
  if (!match)
    return undefined
  const raw = match[1].trim()
  const quoted = (raw.startsWith("'") && raw.endsWith("'"))
    || (raw.startsWith('"') && raw.endsWith('"'))
  return { raw, value: quoted ? raw.slice(1, -1) : raw, quoted }
}

export function validateSectionFrontmatter(section, markdown) {
  const blocks = frontmatterBlocks(markdown)
  const cover = blocks.find((block) => scalar(block, 'layout')?.value === 'section-cover')
    ?? blocks.find((block) => scalar(block, 'day'))
    ?? ''
  const problems = []
  if (scalar(cover, 'day')?.value !== `Day ${section.day}`)
    problems.push(`day must be Day ${section.day}`)
  if (scalar(cover, 'section')?.value !== section.id.slice(1))
    problems.push(`section must be '${section.id.slice(1)}'`)
  if (scalar(cover, 'tier')?.value !== section.tier)
    problems.push(`tier must be ${section.tier}`)

  if (problems.length)
    throw new Error(`${section.id} frontmatter contradiction: ${problems.join('; ')}`)
  return true
}

export function validateSyllabusCatalog(manifest, markdown) {
  const rows = new Map()
  for (const line of markdown.split('\n')) {
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim())
    if (/^S\d{2}$/.test(cells[0] ?? '')
      && ['core', 'recommended', 'optional'].includes(cells[2])
      && /^[123]$/.test(cells[3] ?? '')) {
      if (rows.has(cells[0]))
        throw new Error(`Duplicate ${cells[0]} syllabus catalog row`)
      rows.set(cells[0], cells)
    }
  }
  for (const section of manifest) {
    const row = rows.get(section.id)
    if (!row)
      throw new Error(`${section.id} is missing from the syllabus catalog`)
    const [, , tier, day, status] = row
    const problems = []
    if (tier !== section.tier)
      problems.push(`tier must be ${section.tier}`)
    if (day !== String(section.day))
      problems.push(`day must be ${section.day}`)
    if (status !== section.status)
      problems.push(`status must be ${section.status}`)
    if (problems.length)
      throw new Error(`${section.id} syllabus contradiction: ${problems.join('; ')}`)
  }
  return true
}

export function validateSyllabusTimings(manifest, markdown) {
  const rows = new Map()
  for (const line of markdown.split('\n')) {
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim())
    const id = cells[0]?.match(/^S\d{2}/)?.[0]
    if (!id || cells.length !== 4 || !/^\d+$/.test(cells[2] ?? '') || !/^\d+$/.test(cells[3] ?? ''))
      continue
    if (rows.has(id))
      throw new Error(`Duplicate ${id} syllabus timing row`)
    rows.set(id, { slides: Number(cells[2]), lab: Number(cells[3]) })
  }
  for (const section of manifest) {
    const row = rows.get(section.id)
    if (!row)
      throw new Error(`${section.id} is missing from the syllabus timing table`)
    const problems = []
    if (row.slides !== section.slidesMinutes)
      problems.push(`slides must be ${section.slidesMinutes}`)
    if (row.lab !== section.labMinutes)
      problems.push(`lab time must be ${section.labMinutes}`)
    if (problems.length)
      throw new Error(`${section.id} syllabus timing contradiction: ${problems.join('; ')}`)
  }
  return true
}

export function validateRunbookTimings(manifest, markdown) {
  const rows = new Map()
  for (const line of markdown.split('\n')) {
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim())
    const id = cells[0]?.match(/^S\d{2}$/)?.[0]
    if (!id || !['core', 'recommended', 'optional'].includes(cells[2] ?? ''))
      continue
    if (rows.has(id))
      continue
    rows.set(id, cells)
  }
  for (const section of manifest) {
    const row = rows.get(section.id)
    if (!row)
      throw new Error(`${section.id} is missing from docs/facilitator-runbook.md`)
    const [, , tier] = row
    if (tier !== section.tier)
      throw new Error(`${section.id} runbook tier contradiction: tier must be ${section.tier}`)
  }
  return true
}

export function canonicalDayTotals(manifest = sections) {
  const totals = new Map([1, 2, 3].map((day) => [day, { slides: 0, lab: 0, total: 0 }]))
  for (const section of manifest.filter((item) => item.canonical)) {
    const day = totals.get(section.day)
    day.slides += section.slidesMinutes
    day.lab += section.labMinutes
    day.total += section.slidesMinutes + section.labMinutes
  }
  return totals
}

export function dayOneFitTotal(manifest = sections) {
  return manifest
    .filter((section) => section.day === 1 && section.canonical && section.compressedSlides)
    .reduce((sum, section) => sum + section.compressedSlides, 0)
}

export function dayOneSupersetSlidesTotal(manifest = sections) {
  return manifest
    .filter((section) => section.day === 1)
    .reduce((sum, section) => sum + section.slidesMinutes, 0)
}

export function validatePlanningLanguage(markdown, manifest = sections) {
  const measuredNumber = /\b(?:measured|actual)\b[^\n.]{0,120}\b\d+\s*(?:min(?:ute)?s?)\b/i
  const measuredNumberReverse = /\b\d+\s*(?:min(?:ute)?s?)\b[^\n.]{0,120}\b(?:measured|actual)\b/i
  const statements = markdown.replaceAll('\n', ' ').split(/(?<=[.!?])\s+/)
  for (const statement of statements) {
    const withoutNegations = statement
      .replace(
        /\bneither\s+(?:measured|actual)\s+(?:facts?|timings?|durations?|totals?|time)\s+nor\s+(?:measured|actual)\s+(?:facts?|timings?|durations?|totals?|time)\b/gi,
        '',
      )
      .replace(
        /\b(?:not|never|isn['’]t|aren['’]t|is not|are not|was not|were not)\s+(?:actually\s+)?(?:measured|actual)\b/gi,
        '',
      )
    const timingSubject = /\b(?:facts?|timings?|durations?|totals?|time)\b/i
    if (measuredNumber.test(withoutNegations) || measuredNumberReverse.test(withoutNegations))
      throw new Error('An unrehearsed planning estimate is presented as measured timing')
    if (/\b(?:measured|actual)\b/i.test(withoutNegations) && timingSubject.test(withoutNegations))
      throw new Error('An unrehearsed planning estimate is presented as measured timing')
  }

  const dayOneSuperset = dayOneSupersetSlidesTotal(manifest)
  const dayOneFit = dayOneFitTotal(manifest)
  if (/\b655\b/.test(markdown) && !markdown.includes(String(dayOneSuperset)))
    throw new Error(`README Day 1 superset total must be ${dayOneSuperset}`)
  if (/\b390\b/.test(markdown) && !markdown.includes(String(dayOneFit)))
    throw new Error(`README Day 1 fit-plan target must be ${dayOneFit}`)

  // The two guards above are `includes()` checks with no proximity requirement,
  // so they go quiet as soon as the literals they name stop being the current
  // totals. The published fit-plan arithmetic (`**A → B → … → Z**`) is the real
  // statement of the plan, so bind its endpoints to the computed values: the
  // first chain must start at the superset total and the last must end at the
  // fit-plan target. No chain in the document is a no-op, not a pass.
  const fitChains = [...markdown.matchAll(/\*\*\s*(\d+(?:\s*→\s*\d+)+)\s*\*\*/g)]
    .map((match) => match[1].split('→').map((value) => Number(value.trim())))
  if (fitChains.length) {
    const chainStart = fitChains[0][0]
    const chainEnd = fitChains.at(-1).at(-1)
    if (chainStart !== dayOneSuperset)
      throw new Error(`README fit-plan chain starts at ${chainStart}; expected ${dayOneSuperset}`)
    if (chainEnd !== dayOneFit)
      throw new Error(`README fit-plan chain ends at ${chainEnd}; expected ${dayOneFit}`)
  }

  const totals = canonicalDayTotals(manifest)
  for (const line of markdown.split('\n')) {
    const durations = line.matchAll(/\bDay ([123])\b[^\n]{0,80}?\b(\d+)\s*(?:min(?:ute)?s?)\b/gi)
    for (const match of durations) {
      const day = Number(match[1])
      const value = Number(match[2])
      const expected = totals.get(day)?.total
      if (value !== expected)
        throw new Error(`Day ${day} claims ${value} minutes; expected planning total ${expected}`)
      if (!/\b(?:planned|planning|estimate|target|unrehearsed)\b/i.test(line))
        throw new Error(`${value} min day total must be labelled planned or estimated`)
    }
  }
  return true
}

function parseDeckSections(markdown) {
  const entries = new Map()
  const blocks = markdown.split(/^---\s*$/m)
  for (const block of blocks) {
    const header = block.match(/^#\s*(S\d{2})\s*·[^\n]*/m)
    if (!header)
      continue
    const id = header[1]
    const parts = header[0].split('·').map((part) => part.trim())
    const tier = parts[parts.length - 2]
    const hideMatch = block.match(/^\s*hide:\s*(true|false)\s*$/m)
    entries.set(id, { tier, hide: hideMatch?.[1] })
  }
  return entries
}

export function validateDeckTierTruth(manifest = sections, { repoRoot = resolve(import.meta.dirname, '..') } = {}) {
  const supersetPath = resolve(repoRoot, 'slides.md')
  const cutPath = resolve(repoRoot, 'slides-3day.md')
  if (!existsSync(supersetPath) || !existsSync(cutPath))
    throw new Error('slides.md and slides-3day.md are required for tier truth checks')

  const manifestById = new Map(manifest.map((section) => [section.id, section]))
  const superset = parseDeckSections(readFileSync(supersetPath, 'utf8'))
  const cut = parseDeckSections(readFileSync(cutPath, 'utf8'))

  for (const [id, section] of manifestById) {
    const superEntry = superset.get(id)
    const cutEntry = cut.get(id)
    if (superEntry && cutEntry && superEntry.tier !== cutEntry.tier) {
      throw new Error(
        `tier drift: ${id} is '${superEntry.tier}' in slides.md but '${cutEntry.tier}' in slides-3day.md`,
      )
    }
    if (superEntry && superEntry.tier !== section.tier) {
      throw new Error(
        `tier drift: ${id} is '${superEntry.tier}' in slides.md but manifest requires '${section.tier}'`,
      )
    }
    if (cutEntry && cutEntry.tier !== section.tier) {
      throw new Error(
        `tier drift: ${id} is '${cutEntry.tier}' in slides-3day.md but manifest requires '${section.tier}'`,
      )
    }
    if (superEntry?.hide === 'true')
      throw new Error(`hide invariant: ${id} must stay visible (hide:false) in slides.md superset`)
    if (cutEntry) {
      const expectedHide = section.tier === 'optional' ? 'true' : 'false'
      if (cutEntry.hide !== expectedHide) {
        throw new Error(
          `hide invariant: ${id} is '${section.tier}' but hide='${cutEntry.hide ?? '-'}' in slides-3day.md`,
        )
      }
    }
  }
  return true
}

function renderImport(section, { deck }) {
  const header = `# ${section.id} · ${section.title} · ${section.tier} · Day ${section.day}`
  const fitComment = deck === 'cut' && section.fitPlan ? `# DAY1-FIT: ${section.fitPlan}\n` : ''
  const hideLine = deck === 'superset' || deck === 'cut'
    ? `hide: ${section.tier === 'optional' && deck === 'cut' ? 'true' : 'false'}`
    : null
  return [
    '---',
    fitComment + header,
    `src: ${sectionPath(section)}`,
    ...(hideLine ? [hideLine] : []),
    '---',
  ].join('\n')
}

export function renderDeck(selected, { title, description, deck = 'day', generated = true } = {}) {
  const marker = generated
    ? '<!-- Generated by scripts/generate-decks.mjs from scripts/deck-manifest.mjs. Do not edit. -->\n'
    : ''
  const imports = selected.map((section) => renderImport(section, { deck })).join('\n\n')
  const frontmatter = deck === 'superset'
    ? supersetFrontmatter
    : deck === 'cut'
      ? cutFrontmatter
      : `---
theme: ./theme
title: OpenTofu Practitioner Workshop — ${title}
info: |
  Open source, vendor-neutral OpenTofu workshop.
  ${description}. Sections are imported from the shared section library.
favicon: '/branding/favicon-32.png'
layout: cover
meta: ${title} · OpenTofu-first · LocalStack labs
logo: /branding/logo-512.png
---`
  const coverTitle = deck === 'superset'
    ? 'Infrastructure as Code done right — write it, test it, scale it.\nThe full content superset: sections S00–S28, each individually toggleable.'
    : deck === 'cut'
      ? 'The canonical 3-day cut — core and recommended sections, boiled down from the superset.'
      : `${title} — ${description}.`
  return `${frontmatter}\n${marker}\n# OpenTofu Practitioner Workshop\n\n${coverTitle}\n\n${imports}\n`
}

export function renderGeneratedDecks(manifest = sections) {
  return new Map(generatedDecks.map((deck) => [
    deck.file,
    renderDeck(manifest.filter(deck.select), {
      title: deck.title,
      description: deck.description,
      deck: deck.deck,
    }),
  ]))
}

export function findGeneratedDrift(expected, { repoRoot = resolve(import.meta.dirname, '..') } = {}) {
  return [...expected].flatMap(([file, content]) => {
    const path = resolve(repoRoot, file)
    return !existsSync(path) || readFileSync(path, 'utf8') !== content ? [file] : []
  })
}

export function validateDocumentationTruth(manifest = sections, { repoRoot = resolve(import.meta.dirname, '..') } = {}) {
  validateManifest(manifest, { repoRoot })
  for (const section of manifest) {
    validateSectionFrontmatter(
      section,
      readFileSync(resolve(repoRoot, sectionPath(section)), 'utf8'),
    )
  }
  const syllabus = readFileSync(resolve(repoRoot, 'docs/syllabus.md'), 'utf8')
  validateSyllabusCatalog(manifest, syllabus)
  validateSyllabusTimings(manifest, syllabus)
  validateRunbookTimings(manifest, readFileSync(resolve(repoRoot, 'docs/facilitator-runbook.md'), 'utf8'))
  validatePlanningLanguage(readFileSync(resolve(repoRoot, 'README.md'), 'utf8'), manifest)
  validateDeckTierTruth(manifest, { repoRoot })
  return true
}
