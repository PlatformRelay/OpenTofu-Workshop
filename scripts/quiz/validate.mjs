import { readFileSync } from 'node:fs'
import path from 'node:path'
import Ajv2020 from 'ajv/dist/2020.js'
import { sections as deckSections } from '../deck-manifest.mjs'

const COVERAGE_FLOOR = 3

const root = path.resolve(import.meta.dirname, '../..')
const bankPath = path.resolve(process.argv[2] ?? path.join(root, 'quiz/questions.json'))
const bank = JSON.parse(readFileSync(bankPath, 'utf8'))
const schema = JSON.parse(readFileSync(path.join(root, 'quiz/questions.schema.json'), 'utf8'))
const errors = []
const ids = new Set()
const perSection = new Map()
const knownSections = new Set(deckSections.map(section => section.id))
const canonicalSections = new Set(deckSections.filter(section => section.canonical).map(section => section.id))
const ajv = new Ajv2020({ allErrors: true, strict: true })
const validateSchema = ajv.compile(schema)

if (!validateSchema(bank)) {
  errors.push(...validateSchema.errors.map(error =>
    `schema ${error.instancePath || '/'} ${error.message}`,
  ))
}

for (const [index, question] of (bank.questions ?? []).entries()) {
  const label = question.id ?? `question[${index}]`
  if (!/^S\d{2}-Q-[A-Z0-9-]+$/.test(question.id ?? '')) errors.push(`${label}: invalid question id`)
  if (ids.has(question.id)) errors.push(`${label}: duplicate question id`)
  ids.add(question.id)
  if (!/^S\d{2}$/.test(question.section ?? '') || !question.id?.startsWith(`${question.section}-`)) {
    errors.push(`${label}: section must match the question id`)
  }
  if (!knownSections.has(question.section)) {
    errors.push(`${label}: unknown section ${question.section}`)
  } else if (!canonicalSections.has(question.section)) {
    errors.push(`${label}: non-canonical section ${question.section} (only canonical sections carry self-checks)`)
  }
  perSection.set(question.section, (perSection.get(question.section) ?? 0) + 1)
  if (!Array.isArray(question.options) || question.options.length < 3 || question.options.length > 5) {
    continue
  }
  const optionIds = question.options.map(option => option.id)
  if (new Set(optionIds).size !== optionIds.length) errors.push(`${label}: duplicate option id`)
  if (optionIds.filter(id => id === question.answer).length !== 1) {
    errors.push(`${label}: answer must name exactly one option`)
  }
}

// Coverage floor (US-D-QUIZ-BANK): every canonical section in the deck manifest
// must keep at least COVERAGE_FLOOR questions, so coverage cannot silently
// regress back toward the 3-question prototype.
for (const section of [...canonicalSections].sort()) {
  const count = perSection.get(section) ?? 0
  if (count < COVERAGE_FLOOR) {
    errors.push(`coverage floor: canonical section ${section} has ${count} question(s); needs >= ${COVERAGE_FLOOR}`)
  }
}

if (errors.length) {
  process.stderr.write(`${errors.join('\n')}\n`)
  process.exit(1)
}

process.stdout.write(`Validated ${ids.size} questions across ${perSection.size} sections.\n`)
