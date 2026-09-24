// Mutation probes for scripts/claims-check.mjs.
//
// The checker guards docs/claims-verification.md against pointers that rot
// while every gate stays green. Until this file existed nothing exercised the
// checker's own logic: tests/shell/ci-contract.bats proves it is WIRED, and
// nothing proved it FAILS on the defects it names. It did not: swapping one
// real Where pointer for an unresolvable token and duplicating another real
// one elsewhere netted the exact total and exit 0 -- a silent skip inside the
// guard against silent skips. Each probe here copies the live document, plants
// one defect, and asserts the checker reds on it with the message a human
// would need. Every replacement is asserted to have happened, so a document
// edit that moves a fixture line fails loudly here rather than turning a probe
// into a no-op.
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'

const root = path.resolve(import.meta.dirname, '..')
const script = path.join(root, 'scripts', 'claims-check.mjs')
const doc = readFileSync(path.join(root, 'docs', 'claims-verification.md'), 'utf8')

function run(mutate) {
  const dir = mkdtempSync(path.join(tmpdir(), 'claims-check-'))
  try {
    const file = path.join(dir, 'claims-verification.md')
    writeFileSync(file, mutate(doc))
    const r = spawnSync(process.execPath, [script, file], { cwd: root, encoding: 'utf8' })
    return { status: r.status, out: `${r.stdout}${r.stderr}` }
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

/** Replace exactly one occurrence, and refuse to be a no-op. */
function replaceOnce(text, from, to) {
  const at = text.indexOf(from)
  assert.notEqual(at, -1, `fixture text not found in document: ${from}`)
  assert.equal(text.indexOf(from, at + 1), -1, `fixture text is not unique: ${from}`)
  return text.slice(0, at) + to + text.slice(at + from.length)
}

// Fixture anchors, spelled out so a failure names what moved.
const A1_ROW = '| A1 | Current baseline is OpenTofu **1.12.x** | `pages/S10-opentofu-differentiators/index.md:65`; `pages/S01-iac/index.md:456` |'
const D1_CLAIM = '| D1 | `TOFU_VERSION=1.10.3` |'
const D1_SECOND = '`pages/S01-iac/index.md:457`'
const D2_ROW = '| D2 | `GO_VERSION=1.23.6` | `versions.env:27` |'

test('the live document passes, with nothing unresolvable', () => {
  const r = run((d) => d)
  assert.equal(r.status, 0, r.out)
  assert.match(r.out, /0 failed/)
  assert.match(r.out, /\(0 unresolvable\)/)
})

test('removing a table row changes the exact pointer total', () => {
  const r = run((d) => {
    const line = d.split('\n').find((l) => l.startsWith(A1_ROW))
    assert.ok(line, 'A1 row present')
    return replaceOnce(d, `${line}\n`, '')
  })
  assert.equal(r.status, 1)
  assert.match(r.out, /expected exactly \d+ - evidence was added or removed/)
})

test('an unresolvable pointer is reported even when the exact total still balances', () => {
  // One real pointer becomes a token that is not a path, and another real
  // pointer is repeated so the count stays at the expected total. Before the
  // fix this was exit 0 with "157 Where pointer(s) checked".
  const r = run((d) =>
    replaceOnce(
      d,
      A1_ROW,
      A1_ROW.replace(
        '`pages/S01-iac/index.md:456`',
        '`FAKE_UNCHECKED:456`; `pages/S10-opentofu-differentiators/index.md:65`'
      )
    )
  )
  assert.equal(r.status, 1)
  assert.match(r.out, /`FAKE_UNCHECKED:456` is not resolvable as a path and was not checked/)
  assert.match(r.out, /\(1 unresolvable\)/)
  assert.doesNotMatch(r.out, /expected exactly/)
})

test('a pointer past the end of its file is named', () => {
  const r = run((d) => replaceOnce(d, D2_ROW, D2_ROW.replace(':27', ':9999')))
  assert.equal(r.status, 1)
  assert.match(r.out, /versions\.env:9999 is past EOF/)
})

test('a pin pointer that resolves to the wrong line is named, with the line it found', () => {
  // versions.env:28 is the blank line after GO_VERSION. The D2 class of rot.
  const r = run((d) => replaceOnce(d, D2_ROW, D2_ROW.replace(':27', ':28')))
  assert.equal(r.status, 1)
  assert.match(r.out, /D2: versions\.env:28 does not mention GO_VERSION/)
  assert.match(r.out, /line 28 reads:/)
})

test('a second pointer in a pin row is anchored too, by name or value', () => {
  // pages/S01-iac/index.md:457 says "pins **1.10.3**"; 455 is blank.
  const r = run((d) => replaceOnce(d, D1_SECOND, '`pages/S01-iac/index.md:455`'))
  assert.equal(r.status, 1)
  assert.match(r.out, /D1: pages\/S01-iac\/index\.md:455 does not mention TOFU_VERSION or 1\.10\.3/)
})

test('a pin row whose claim loses its code span is counted as unrecognised, not skipped', () => {
  const r = run((d) => replaceOnce(d, D1_CLAIM, '| D1 | TOFU_VERSION=1.10.3 |'))
  assert.equal(r.status, 1)
  assert.match(r.out, /a pin row stopped being recognised/)
})

test('a D row that disappears is counted', () => {
  const r = run((d) => {
    const line = d.split('\n').find((l) => l.startsWith('| D4 |'))
    assert.ok(line, 'D4 row present')
    return replaceOnce(d, `${line}\n`, '')
  })
  assert.equal(r.status, 1)
  assert.match(r.out, /D<n> row\(s\) found, expected 5/)
})
