import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { sections as deckSections } from '../deck-manifest.mjs'

const root = path.resolve(import.meta.dirname, '../..')
const questionsPath = path.join(root, 'quiz/questions.json')
const canonical = deckSections.filter(section => section.canonical)

function run(script, args = []) {
  return execFileSync(process.execPath, [path.join(root, script), ...args], {
    cwd: root,
    encoding: 'utf8',
  })
}

function loadBank() {
  return JSON.parse(readFileSync(questionsPath, 'utf8'))
}

function scratchBank(prefix, bank) {
  const directory = mkdtempSync(path.join(tmpdir(), prefix))
  const bankPath = path.join(directory, 'bank.json')
  writeFileSync(bankPath, JSON.stringify(bank))
  return { directory, bankPath }
}

test('bank validates and covers every canonical section at the floor', () => {
  const bank = loadBank()
  const sections = new Set(bank.questions.map(question => question.section))
  const output = run('scripts/quiz/validate.mjs')
  assert.match(output, new RegExp(`${bank.questions.length} questions across ${sections.size} sections`))

  // Redundant with the validator's own floor rule by design: if the rule is
  // ever weakened, this test still names the section that fell below the floor.
  for (const section of canonical) {
    const count = bank.questions.filter(question => question.section === section.id).length
    assert.ok(count >= 3, `${section.id} has ${count} questions; canonical floor is 3`)
  }
})

test('validator rejects duplicate IDs and an answer outside the option set', () => {
  const bank = loadBank()
  bank.questions[1].id = bank.questions[0].id
  bank.questions[2].answer = 'missing'
  bank.questions[0].difficulty = 'impossible'
  bank.questions[0].unsupported = true
  bank.questions[1].section = 'S99'
  const { bankPath } = scratchBank('quiz-invalid-', bank)

  assert.throws(
    () => run('scripts/quiz/validate.mjs', [bankPath]),
    error => {
      assert.match(error.stderr, /duplicate question id/)
      assert.match(error.stderr, /answer must name exactly one option/)
      assert.match(error.stderr, /difficulty.*allowed values/)
      assert.match(error.stderr, /additional properties/)
      assert.match(error.stderr, /unknown section S99/)
      return true
    },
  )
})

test('validator enforces the >=3-per-canonical-section coverage floor', () => {
  const bank = loadBank()
  const index = bank.questions.findIndex(question => question.section === 'S12')
  assert.ok(index >= 0, 'expected the bank to contain S12 questions')
  bank.questions.splice(index, 1)
  const { bankPath } = scratchBank('quiz-floor-', bank)

  assert.throws(
    () => run('scripts/quiz/validate.mjs', [bankPath]),
    error => {
      assert.match(error.stderr, /coverage floor: canonical section S12 has 2 question\(s\); needs >= 3/)
      return true
    },
  )
})

test('validator names non-canonical sections as errors', () => {
  const nonCanonical = deckSections.find(section => !section.canonical)
  const bank = loadBank()
  bank.questions[0].section = nonCanonical.id
  bank.questions[0].id = `${nonCanonical.id}-Q-01`
  const { bankPath } = scratchBank('quiz-tier-', bank)

  assert.throws(
    () => run('scripts/quiz/validate.mjs', [bankPath]),
    error => {
      assert.match(error.stderr, new RegExp(`non-canonical section ${nonCanonical.id}`))
      return true
    },
  )
})

test('JSON Schema rejects empty banks, empty references, and malformed option IDs', () => {
  const bank = loadBank()
  bank.questions[0].references = []
  bank.questions[0].options[0].id = 'INVALID!'
  bank.questions.splice(1)
  const { bankPath } = scratchBank('quiz-schema-', bank)

  assert.throws(
    () => run('scripts/quiz/validate.mjs', [bankPath]),
    error => {
      assert.match(error.stderr, /references.*must NOT have fewer than 1 items/)
      assert.match(error.stderr, /options\/0\/id.*must match pattern/)
      return true
    },
  )

  bank.questions = []
  writeFileSync(bankPath, JSON.stringify(bank))
  assert.throws(
    () => run('scripts/quiz/validate.mjs', [bankPath]),
    error => {
      assert.match(error.stderr, /questions.*must NOT have fewer than 1 items/)
      return true
    },
  )
})

test('offline export hides answers in participant copy and reveals reasoning separately', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'quiz-export-'))
  run('scripts/quiz/export.mjs', ['--out', directory])

  const participant = readFileSync(path.join(directory, 'participant.md'), 'utf8')
  const facilitator = readFileSync(path.join(directory, 'facilitator.md'), 'utf8')
  const bank = loadBank()

  assert.doesNotMatch(participant, /Answer:/)
  for (const question of bank.questions) {
    assert.match(participant, new RegExp(`## ${question.section} · ${question.id}`))
    assert.match(facilitator, new RegExp(question.explanation.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  }
  assert.equal((facilitator.match(/Answer: \*\*/g) ?? []).length, bank.questions.length)
})

test('day export resolves its sections from the deck manifest, not a day list', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'quiz-export-day-'))
  run('scripts/quiz/export.mjs', ['--out', directory, '--day', '2'])

  const participant = readFileSync(path.join(directory, 'participant-day-2.md'), 'utf8')
  const facilitator = readFileSync(path.join(directory, 'facilitator-day-2.md'), 'utf8')
  const expected = new Set(canonical.filter(section => section.day === 2).map(section => section.id))
  const emitted = new Set([...participant.matchAll(/^## (S\d{2}) ·/gm)].map(match => match[1]))

  assert.deepEqual([...emitted].sort(), [...expected].sort())
  assert.doesNotMatch(participant, /Answer:/)
  assert.match(facilitator, /Answer: \*\*/)
  assert.match(participant, /Day 2 self-check/)
})

test('day export fails with named errors for an uncovered day and a bad selector', () => {
  const bank = loadBank()
  const dayOne = new Set(canonical.filter(section => section.day === 1).map(section => section.id))
  bank.questions = bank.questions.filter(question => dayOne.has(question.section))
  const { directory, bankPath } = scratchBank('quiz-empty-day-', bank)

  assert.throws(
    () => run('scripts/quiz/export.mjs', ['--out', directory, '--bank', bankPath, '--day', '2']),
    error => {
      assert.match(error.stderr, /day 2 has zero questions/)
      return true
    },
  )
  assert.throws(
    () => run('scripts/quiz/export.mjs', ['--out', directory, '--day', '9']),
    error => {
      assert.match(error.stderr, /invalid day selector '9'/)
      return true
    },
  )
})
