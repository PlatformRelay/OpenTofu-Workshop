import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'

const root = path.resolve(import.meta.dirname, '../..')
const questionsPath = path.join(root, 'quiz/questions.prototype.json')

function run(script, args = []) {
  return execFileSync(process.execPath, [path.join(root, script), ...args], {
    cwd: root,
    encoding: 'utf8',
  })
}

test('prototype bank validates three stable section and question IDs', () => {
  const output = run('scripts/quiz/validate.mjs')
  assert.match(output, /3 questions across 3 sections/)
})

test('validator rejects duplicate IDs and an answer outside the option set', () => {
  const bank = JSON.parse(readFileSync(questionsPath, 'utf8'))
  bank.questions[1].id = bank.questions[0].id
  bank.questions[2].answer = 'missing'
  bank.questions[0].difficulty = 'impossible'
  bank.questions[0].unsupported = true
  bank.questions[1].section = 'S99'
  const directory = mkdtempSync(path.join(tmpdir(), 'quiz-invalid-'))
  const invalidPath = path.join(directory, 'invalid.json')
  writeFileSync(invalidPath, JSON.stringify(bank))

  assert.throws(
    () => run('scripts/quiz/validate.mjs', [invalidPath]),
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

test('JSON Schema rejects empty banks, empty references, and malformed option IDs', () => {
  const bank = JSON.parse(readFileSync(questionsPath, 'utf8'))
  bank.questions[0].references = []
  bank.questions[0].options[0].id = 'INVALID!'
  bank.questions.splice(1)
  const directory = mkdtempSync(path.join(tmpdir(), 'quiz-schema-'))
  const invalidPath = path.join(directory, 'invalid.json')
  writeFileSync(invalidPath, JSON.stringify(bank))

  assert.throws(
    () => run('scripts/quiz/validate.mjs', [invalidPath]),
    error => {
      assert.match(error.stderr, /references.*must NOT have fewer than 1 items/)
      assert.match(error.stderr, /options\/0\/id.*must match pattern/)
      return true
    },
  )

  bank.questions = []
  writeFileSync(invalidPath, JSON.stringify(bank))
  assert.throws(
    () => run('scripts/quiz/validate.mjs', [invalidPath]),
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
  const bank = JSON.parse(readFileSync(questionsPath, 'utf8'))

  for (const question of bank.questions) {
    assert.doesNotMatch(participant, new RegExp(`Answer:.*${question.answer}`))
    assert.match(facilitator, new RegExp(`Answer:.*${question.answer}`))
    assert.match(facilitator, new RegExp(question.explanation.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  }
})
