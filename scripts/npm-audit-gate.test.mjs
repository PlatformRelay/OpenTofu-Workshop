import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import test from 'node:test'

import { evaluateAudit, loadAuditJson } from './npm-audit-gate.mjs'

const root = path.resolve(import.meta.dirname, '..')
const gate = path.join(root, 'scripts', 'npm-audit-gate.mjs')
const fixtures = path.join(root, 'scripts', 'fixtures', 'npm-audit')

const TODAY = '2026-08-18'

function fixturePath(name) {
  return path.join(fixtures, name)
}

async function fixture(name) {
  return JSON.parse(await readFile(fixturePath(name), 'utf8'))
}

function exception(overrides = {}) {
  return {
    id: 'GHSA-w3rx-r6r6-pgpr',
    reason: 'no patched release published on the registry',
    owner: '@PlatformRelay',
    expires: '2026-12-31',
    ...overrides,
  }
}

// Always close the child's stdin: the gate reads stdin when the source is "-",
// so a test that never ends the stream would hang instead of failing.
function cli(args, { input = '' } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [gate, ...args], { cwd: root, stdio: ['pipe', 'pipe', 'pipe'] })
    let stdout = ''
    let stderr = ''
    child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk })
    child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk })
    child.on('error', reject)
    child.on('close', (code) => resolve({ code, stdout, stderr }))
    child.stdin.on('error', () => {})
    child.stdin.end(input)
  })
}

// --- blocking findings -------------------------------------------------------

test('an unexcepted high advisory blocks', async () => {
  const result = evaluateAudit({ audit: await fixture('high-findings.json'), exceptions: [], today: TODAY })

  assert.equal(result.ok, false)
  assert.ok(result.blocking.some((entry) => entry.id === 'GHSA-2v37-7h3g-55p8'))
  assert.ok(result.errors.some((error) => error.includes('GHSA-2v37-7h3g-55p8')))
  assert.ok(result.errors.some((error) => error.includes('nanoid')))
})

test('an unexcepted critical advisory blocks', async () => {
  const audit = {
    advisories: {
      1: {
        id: 1,
        github_advisory_id: 'GHSA-aaaa-bbbb-cccc',
        module_name: 'left-pad',
        severity: 'critical',
        title: 'RCE',
        url: 'https://github.com/advisories/GHSA-aaaa-bbbb-cccc',
        vulnerable_versions: '<1.0.0',
        patched_versions: '>=1.0.0',
        findings: [],
      },
    },
    metadata: { vulnerabilities: { info: 0, low: 0, moderate: 0, high: 0, critical: 1 } },
  }

  const result = evaluateAudit({ audit, exceptions: [], today: TODAY })

  assert.equal(result.ok, false)
  assert.ok(result.blocking.some((entry) => entry.severity === 'critical'))
})

test('moderate and low advisories never block', async () => {
  const result = evaluateAudit({ audit: await fixture('moderate-low-only.json'), exceptions: [], today: TODAY })

  assert.deepEqual(result.errors, [])
  assert.equal(result.ok, true)
  assert.deepEqual(result.blocking, [])
})

test('a clean audit passes with an empty exception list', async () => {
  const result = evaluateAudit({ audit: await fixture('clean.json'), exceptions: [], today: TODAY })

  assert.deepEqual(result.errors, [])
  assert.equal(result.ok, true)
})

// --- exceptions --------------------------------------------------------------

test('a valid unexpired exception clears its advisory', async () => {
  const audit = await fixture('high-findings.json')
  const exceptions = [
    exception({ id: 'GHSA-w3rx-r6r6-pgpr' }),
    exception({ id: 'GHSA-5p2g-fcmc-qvqq' }),
    exception({ id: 'GHSA-2v37-7h3g-55p8' }),
  ]

  const result = evaluateAudit({ audit, exceptions, today: TODAY })

  assert.deepEqual(result.errors, [])
  assert.equal(result.ok, true)
  assert.equal(result.excepted.length, 3)
})

test('an expired exception fails the gate and stops shielding its advisory', async () => {
  const audit = await fixture('high-findings.json')
  const exceptions = [
    exception({ id: 'GHSA-w3rx-r6r6-pgpr', expires: '2026-08-17' }),
    exception({ id: 'GHSA-5p2g-fcmc-qvqq' }),
    exception({ id: 'GHSA-2v37-7h3g-55p8' }),
  ]

  const result = evaluateAudit({ audit, exceptions, today: TODAY })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('expired on 2026-08-17')))
  assert.ok(result.blocking.some((entry) => entry.id === 'GHSA-w3rx-r6r6-pgpr'))
})

test('an exception expiring today is still valid', async () => {
  const audit = await fixture('high-findings.json')
  const exceptions = [
    exception({ id: 'GHSA-w3rx-r6r6-pgpr', expires: TODAY }),
    exception({ id: 'GHSA-5p2g-fcmc-qvqq', expires: TODAY }),
    exception({ id: 'GHSA-2v37-7h3g-55p8', expires: TODAY }),
  ]

  const result = evaluateAudit({ audit, exceptions, today: TODAY })

  assert.deepEqual(result.errors, [])
  assert.equal(result.ok, true)
})

for (const field of ['id', 'reason', 'owner', 'expires']) {
  test(`an exception missing "${field}" fails the gate`, async () => {
    const entry = exception()
    delete entry[field]

    const result = evaluateAudit({ audit: await fixture('clean.json'), exceptions: [entry], today: TODAY })

    assert.equal(result.ok, false)
    assert.ok(result.errors.some((error) => error.includes('require id, reason, owner, and expires')))
  })
}

test('an exception with a non-ISO expiry fails the gate', async () => {
  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: [exception({ expires: '31-12-2026' })],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('invalid expiry date')))
})

test('an exception with an impossible calendar date fails the gate', async () => {
  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: [exception({ expires: '2026-02-30' })],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('invalid expiry date')))
})

test('an exception id that is not a GHSA identifier fails the gate', async () => {
  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: [exception({ id: '1130733' })],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('GHSA advisory id')))
})

test('duplicate exception ids fail the gate', async () => {
  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: [exception(), exception()],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('duplicate')))
})

test('a non-array exception registry fails closed', async () => {
  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: { 'GHSA-w3rx-r6r6-pgpr': true },
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('npmAdvisories must be an array')))
})

// --- fail-closed on unusable audit data --------------------------------------

test('a null audit payload fails closed', () => {
  const result = evaluateAudit({ audit: null, exceptions: [], today: TODAY })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('audit data is not a JSON object')))
})

test('audit output without a metadata block fails closed', async () => {
  const result = evaluateAudit({ audit: await fixture('missing-metadata.json'), exceptions: [], today: TODAY })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('metadata.vulnerabilities')))
})

test('non-numeric severity counts fail closed', () => {
  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 'none', critical: 0 } } },
    exceptions: [],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('metadata.vulnerabilities.high')))
})

test('an advisories value that is not an object fails closed', () => {
  const result = evaluateAudit({
    audit: { advisories: [], metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: [],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('advisories must be an object')))
})

test('an advisory entry missing its GHSA id fails closed', () => {
  const result = evaluateAudit({
    audit: {
      advisories: { 1: { id: 1, module_name: 'x', severity: 'high', findings: [] } },
      metadata: { vulnerabilities: { high: 1, critical: 0 } },
    },
    exceptions: [],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('github_advisory_id')))
})

test('an advisory entry with an unknown severity fails closed', () => {
  const result = evaluateAudit({
    audit: {
      advisories: {
        1: { id: 1, github_advisory_id: 'GHSA-aaaa-bbbb-cccc', module_name: 'x', severity: 'spicy', findings: [] },
      },
      metadata: { vulnerabilities: { high: 0, critical: 0 } },
    },
    exceptions: [],
    today: TODAY,
  })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('unknown severity')))
})

test('fewer enumerated high advisories than metadata reports fails closed', async () => {
  const result = evaluateAudit({ audit: await fixture('under-enumerated.json'), exceptions: [], today: TODAY })

  assert.equal(result.ok, false)
  assert.ok(result.errors.some((error) => error.includes('truncated')))
})

test('loadAuditJson rejects an empty payload', async () => {
  await assert.rejects(
    () => loadAuditJson(fixturePath('empty.json')),
    /produced no output/,
  )
})

test('loadAuditJson rejects non-JSON audit output', async () => {
  await assert.rejects(
    () => loadAuditJson(fixturePath('not-json.txt')),
    /is not valid JSON/,
  )
})

test('loadAuditJson rejects a missing file', async () => {
  await assert.rejects(
    () => loadAuditJson(fixturePath('does-not-exist.json')),
    /could not be read/,
  )
})

// --- CLI ---------------------------------------------------------------------

test('CLI exits non-zero on an unexcepted high advisory read from a file', async () => {
  const result = await cli([fixturePath('high-findings.json'), '--exceptions', 'none', '--today', TODAY])

  assert.equal(result.code, 1)
  assert.match(result.stderr, /GHSA-2v37-7h3g-55p8/)
})

test('CLI exits zero on a moderate/low-only audit read from stdin', async () => {
  const result = await cli(['-', '--exceptions', 'none', '--today', TODAY], {
    input: await readFile(fixturePath('moderate-low-only.json'), 'utf8'),
  })

  assert.equal(result.code, 0)
  assert.match(result.stdout, /no unexcepted high or critical/i)
})

test('CLI exits non-zero on a missing audit file', async () => {
  const result = await cli([fixturePath('does-not-exist.json'), '--exceptions', 'none', '--today', TODAY])

  assert.equal(result.code, 1)
  assert.match(result.stderr, /could not be read/)
})

test('CLI exits non-zero on empty stdin', async () => {
  const result = await cli(['-', '--exceptions', 'none', '--today', TODAY], { input: '' })

  assert.equal(result.code, 1)
  assert.match(result.stderr, /produced no output/)
})

// --- repository state --------------------------------------------------------

test('the checked-in exception registry is valid and unexpired today', async () => {
  const registry = JSON.parse(await readFile(path.join(root, 'supply-chain', 'exceptions.json'), 'utf8'))
  const today = new Date().toISOString().slice(0, 10)

  const result = evaluateAudit({
    audit: { advisories: {}, metadata: { vulnerabilities: { high: 0, critical: 0 } } },
    exceptions: registry.npmAdvisories ?? [],
    today,
  })

  assert.deepEqual(result.errors, [])
})
