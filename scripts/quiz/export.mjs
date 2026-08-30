import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { sections as deckSections } from '../deck-manifest.mjs'

const root = path.resolve(import.meta.dirname, '../..')

function flagValue(name) {
  const index = process.argv.indexOf(name)
  return index >= 0 ? process.argv[index + 1] : undefined
}

const outValue = flagValue('--out')
if (!outValue) throw new Error('usage: export.mjs --out DIRECTORY [--day 1|2|3] [--bank FILE]')
const outputDirectory = path.resolve(outValue)
const bankPath = path.resolve(flagValue('--bank') ?? path.join(root, 'quiz/questions.json'))
const dayValue = flagValue('--day')
if (process.argv.includes('--day') && !/^[123]$/.test(dayValue ?? '')) {
  throw new Error(`invalid day selector '${dayValue ?? ''}': expected 1, 2, or 3`)
}
const day = dayValue ? Number(dayValue) : undefined

const bank = JSON.parse(readFileSync(bankPath, 'utf8'))

// Sections resolve from the deck manifest SSoT — never a hand-maintained day list.
const canonical = deckSections.filter(section => section.canonical)
const canonicalIds = new Set(canonical.map(section => section.id))
for (const question of bank.questions) {
  if (!canonicalIds.has(question.section)) {
    throw new Error(`non-canonical section ${question.section} in ${question.id}; run quiz:validate`)
  }
}

const selected = day ? canonical.filter(section => section.day === day) : canonical
const sectionOrder = new Map(selected.map((section, index) => [section.id, index]))
const questions = bank.questions
  .filter(question => sectionOrder.has(question.section))
  .sort((a, b) => (sectionOrder.get(a.section) - sectionOrder.get(b.section)) || a.id.localeCompare(b.id))
if (day && questions.length === 0) throw new Error(`day ${day} has zero questions; the bank does not cover it`)

mkdirSync(outputDirectory, { recursive: true })

function renderQuestion(question, reveal) {
  const options = question.options.map(option => `- [ ] **${option.id}** — ${option.text}`).join('\n')
  const answer = reveal
    ? `\n\nAnswer: **${question.answer}**\n\n${question.explanation}\n\n${question.options.map(option => `- **${option.id}:** ${option.rationale}`).join('\n')}`
    : ''
  return `## ${question.section} · ${question.id}\n\n${question.prompt}\n\n${options}${answer}`
}

const scope = day ? ` — Day ${day} self-check` : ''
const header = `# Workshop quiz${scope}\n\nGenerated from \`quiz/questions.json\`; the repository remains the source of truth.`
const suffix = day ? `-day-${day}` : ''
const body = reveal => questions.map(question => renderQuestion(question, reveal)).join('\n\n---\n\n')
writeFileSync(path.join(outputDirectory, `participant${suffix}.md`), `${header}\n\n${body(false)}\n`)
writeFileSync(path.join(outputDirectory, `facilitator${suffix}.md`), `${header}\n\n${body(true)}\n`)
process.stdout.write(`Exported ${questions.length} questions${day ? ` for day ${day}` : ''} to ${outputDirectory}.\n`)
