#!/usr/bin/env node
import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import {
  findGeneratedDrift,
  renderGeneratedDecks,
  sections,
  validateDeckTierTruth,
  validateDocumentationTruth,
  validateManifest,
} from './deck-manifest.mjs'

const repoRoot = resolve(import.meta.dirname, '..')
const check = process.argv.includes('--check')
const checkTiers = process.argv.includes('--check-tiers')

if (checkTiers) {
  validateDeckTierTruth(sections, { repoRoot })
  console.log(`Deck tier truth matches manifest (${sections.length} sections).`)
  process.exit(0)
}

validateManifest(sections, { repoRoot })

if (check) {
  validateDocumentationTruth(sections, { repoRoot })
  const expected = renderGeneratedDecks(sections)
  const drift = findGeneratedDrift(expected, { repoRoot })
  if (drift.length) {
    console.error(`Generated deck drift: ${drift.join(', ')}. Run \`pnpm decks:generate\`.`)
    process.exit(1)
  }
  console.log(`Generated decks are current (${expected.size} entries, ${sections.length} sections).`)
} else {
  validateDocumentationTruth(sections, { repoRoot })
  const expected = renderGeneratedDecks(sections)
  for (const [file, content] of expected)
    writeFileSync(resolve(repoRoot, file), content)
  console.log(`Generated ${expected.size} deck entries from ${sections.length} sections.`)
}
