#!/usr/bin/env node

// Fail-closed dependency-audit gate (US-F-DEP-AUDIT).
//
// Reads `pnpm audit --json` output from a file path or stdin and fails on any
// high/critical advisory that is not covered by a valid, unexpired entry in
// supply-chain/exceptions.json -> npmAdvisories.
//
// "Fail closed" is the whole point: a missing file, empty output, non-JSON
// output, a payload that does not look like an audit report, or an advisory
// list that is shorter than the report's own severity counts all exit
// non-zero. "We could not read the advisories" must never be mistaken for
// "there are no advisories".

import { readFile } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const BLOCKING_SEVERITIES = new Set(['high', 'critical'])
const KNOWN_SEVERITIES = new Set(['info', 'low', 'moderate', 'high', 'critical'])
const GHSA_ID = /^GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}$/
const EXCEPTIONS_FILE = 'supply-chain/exceptions.json'
// An exception is a temporary, re-examined risk acceptance. Capping how far
// ahead `expires` may sit stops `9999-12-31` from masquerading as one.
const MAX_EXCEPTION_DAYS = 180

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isIsoDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value ?? '')) return false
  const parsed = new Date(`${value}T00:00:00Z`)
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim() !== ''
}

/**
 * Validate the npmAdvisories exception registry.
 *
 * Deliberately separate from supply-chain-policy.mjs `validateExceptions()`:
 * that one governs remote-download inputs (source/kind/sha256) and this one
 * governs advisory IDs (id/reason/owner/expires). They share the file, not the
 * shape — neither validator ever sees the other's array.
 */
function validateExceptions(exceptions, today, errors) {
  const byId = new Map()
  if (!Array.isArray(exceptions)) {
    errors.push(`${EXCEPTIONS_FILE}: npmAdvisories must be an array`)
    return byId
  }
  for (const exception of exceptions) {
    if (!isPlainObject(exception)) {
      errors.push(`${EXCEPTIONS_FILE}: npmAdvisories entries must be objects`)
      continue
    }
    const label = isNonEmptyString(exception.id) ? exception.id : '<unnamed entry>'
    if (!isNonEmptyString(exception.id) || !isNonEmptyString(exception.module)
      || !isNonEmptyString(exception.reason) || !isNonEmptyString(exception.owner)
      || !isNonEmptyString(exception.expires)) {
      errors.push(`${EXCEPTIONS_FILE}: npmAdvisories exceptions require id, module, reason, owner, and expires (${label})`)
      continue
    }
    if (!GHSA_ID.test(exception.id)) {
      errors.push(`${EXCEPTIONS_FILE}: ${label} must be a GHSA advisory id such as GHSA-w3rx-r6r6-pgpr, not a registry-internal number`)
      continue
    }
    if (!isIsoDate(exception.expires)) {
      errors.push(`${EXCEPTIONS_FILE}: ${label} has an invalid expiry date (expected YYYY-MM-DD, got ${JSON.stringify(exception.expires)})`)
      continue
    }
    if (exception.expires < today) {
      errors.push(`${EXCEPTIONS_FILE}: ${label} expired on ${exception.expires} — re-verify the advisory, then patch it or renew the exception`)
      continue
    }
    const horizonDays = Math.round(
      (Date.parse(`${exception.expires}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / 86400000,
    )
    if (horizonDays > MAX_EXCEPTION_DAYS) {
      errors.push(`${EXCEPTIONS_FILE}: ${label} expires ${horizonDays} days out, more than ${MAX_EXCEPTION_DAYS} days — an exception is a temporary risk acceptance, not a permanent waiver`)
      continue
    }
    if (byId.has(exception.id)) {
      errors.push(`${EXCEPTIONS_FILE}: duplicate npmAdvisories entry for ${label}`)
      continue
    }
    byId.set(exception.id, exception)
  }
  return byId
}

/**
 * Assert the payload really is a pnpm/npm audit report before trusting it.
 * `metadata.vulnerabilities` with numeric severity counts is the schema
 * witness — a truncated, wrapped, or error payload will not have it.
 */
function validateAuditShape(audit, errors) {
  if (!isPlainObject(audit)) {
    errors.push('audit data is not a JSON object — refusing to treat unreadable output as a clean audit')
    return null
  }
  const vulnerabilities = isPlainObject(audit.metadata) ? audit.metadata.vulnerabilities : undefined
  if (!isPlainObject(vulnerabilities)) {
    errors.push('audit data has no metadata.vulnerabilities block — this is not a pnpm audit report')
    return null
  }
  let counted = true
  for (const severity of KNOWN_SEVERITIES) {
    const count = vulnerabilities[severity]
    // The blocking severities are the schema witness and must be present: an
    // empty `vulnerabilities` object is shaped like a report but proves
    // nothing, and letting it through would read "we could not count the
    // advisories" as "there are no advisories". The informational severities
    // are not load-bearing, so a missing one is tolerated.
    if (count === undefined && !BLOCKING_SEVERITIES.has(severity)) continue
    if (!Number.isInteger(count) || count < 0) {
      errors.push(`audit data has a missing or non-numeric metadata.vulnerabilities.${severity} count (${JSON.stringify(count)})`)
      counted = false
    }
  }
  if (!counted) return null
  // pnpm always emits `advisories`. If it is absent the payload is not a whole
  // report, so its zero counts witness nothing.
  if (!isPlainObject(audit.advisories)) {
    errors.push('audit data has no advisories object keyed by advisory id — this is not a complete pnpm audit report')
    return null
  }
  return { vulnerabilities, advisories: audit.advisories }
}

function collectAdvisories(advisories, errors) {
  const collected = []
  for (const [key, advisory] of Object.entries(advisories)) {
    if (!isPlainObject(advisory)) {
      errors.push(`audit advisory ${key} is not an object`)
      continue
    }
    if (!isNonEmptyString(advisory.github_advisory_id)) {
      errors.push(`audit advisory ${key} has no github_advisory_id — cannot be matched against an exception`)
      continue
    }
    if (!KNOWN_SEVERITIES.has(advisory.severity)) {
      errors.push(`audit advisory ${advisory.github_advisory_id} has an unknown severity ${JSON.stringify(advisory.severity)}`)
      continue
    }
    collected.push({
      id: advisory.github_advisory_id,
      severity: advisory.severity,
      module: isNonEmptyString(advisory.module_name) ? advisory.module_name : '<unknown module>',
      title: isNonEmptyString(advisory.title) ? advisory.title : '',
      vulnerable: advisory.vulnerable_versions ?? '',
      patched: advisory.patched_versions ?? '',
      url: advisory.url ?? `https://github.com/advisories/${advisory.github_advisory_id}`,
    })
  }
  return collected
}

/**
 * Pure decision function — no I/O, no clock, no network.
 *
 * @param {object} options
 * @param {unknown} options.audit parsed `pnpm audit --json` payload
 * @param {unknown} options.exceptions the npmAdvisories array
 * @param {string} options.today ISO date the expiries are judged against
 * @returns {{ok: boolean, errors: string[], blocking: object[], excepted: object[]}}
 */
export function evaluateAudit({ audit, exceptions = [], today = new Date().toISOString().slice(0, 10) } = {}) {
  const errors = []
  const warnings = []
  const exceptionById = validateExceptions(exceptions, today, errors)
  const shape = validateAuditShape(audit, errors)
  if (shape === null) {
    return { ok: false, errors, warnings, blocking: [], excepted: [] }
  }

  const advisories = collectAdvisories(shape.advisories, errors)
  const blockingCandidates = advisories.filter((advisory) => BLOCKING_SEVERITIES.has(advisory.severity))

  // Under-enumeration means we lost advisories somewhere between pnpm and here.
  // Treat that as unreadable data, not as an all-clear.
  for (const severity of BLOCKING_SEVERITIES) {
    const reported = shape.vulnerabilities[severity]
    if (!Number.isInteger(reported)) continue
    const enumerated = blockingCandidates.filter((advisory) => advisory.severity === severity).length
    if (enumerated < reported) {
      errors.push(`audit data is truncated: metadata reports ${reported} ${severity} advisories but only ${enumerated} could be read`)
    }
  }

  const blocking = []
  const excepted = []
  const usedExceptions = new Set()
  for (const advisory of blockingCandidates) {
    const exception = exceptionById.get(advisory.id)
    // A waiver names one package. Matching on the GHSA alone would let an
    // exception written for one dependency travel to a different one.
    if (exception && exception.module !== advisory.module) {
      usedExceptions.add(advisory.id)
      errors.push(`${EXCEPTIONS_FILE}: ${advisory.id} is recorded for module ${exception.module} but the advisory affects ${advisory.module} — the exception does not apply`)
      blocking.push(advisory)
      continue
    }
    if (exception) {
      usedExceptions.add(advisory.id)
      excepted.push({ ...advisory, exception })
      continue
    }
    blocking.push(advisory)
    errors.push(`${advisory.severity} advisory ${advisory.id} in ${advisory.module} (${advisory.vulnerable} → ${advisory.patched || 'no published patch'}) is not covered by an unexpired exception: ${advisory.url}`)
  }

  // A stale exception is reported but never blocks. Erroring would red the gate
  // for a non-security reason — a transitive dependency merely disappearing —
  // and stale-exception detection is outside this gate's remit. The `expires`
  // horizon already caps how long a forgotten waiver can linger.
  for (const id of exceptionById.keys()) {
    if (usedExceptions.has(id)) continue
    warnings.push(`${EXCEPTIONS_FILE}: ${id} no longer matches any high/critical advisory — delete it if the finding is patched or gone`)
  }

  return { ok: errors.length === 0, errors, warnings, blocking, excepted }
}

async function readStdin() {
  const chunks = []
  for await (const chunk of process.stdin) chunks.push(chunk)
  return Buffer.concat(chunks).toString('utf8')
}

/**
 * Read audit JSON from a file path (or stdin when `source` is `-`/undefined),
 * failing loudly on every unusable variant.
 */
export async function loadAuditJson(source) {
  const label = source && source !== '-' ? source : 'stdin'
  let raw
  if (!source || source === '-') {
    raw = await readStdin()
  } else {
    try {
      raw = await readFile(source, 'utf8')
    } catch (error) {
      throw new Error(`audit data at ${label} could not be read: ${error.message}`)
    }
  }
  if (raw.trim() === '') {
    throw new Error(`audit data at ${label} produced no output — the audit command probably failed`)
  }
  try {
    return JSON.parse(raw)
  } catch (error) {
    throw new Error(`audit data at ${label} is not valid JSON: ${error.message}`)
  }
}

/**
 * Load the exception registry, failing closed on every unusable variant.
 *
 * A missing file is an error, not an empty registry. The file is tracked and
 * also carries `remoteInputs`, so its absence means a moved or renamed path —
 * and once every advisory is patched and `npmAdvisories` is legitimately empty,
 * returning [] here would leave the gate running green with no exception
 * governance at all. "Present but empty" is the valid empty case.
 */
export async function loadExceptions(file) {
  let raw
  try {
    raw = await readFile(file, 'utf8')
  } catch (error) {
    throw new Error(`${EXCEPTIONS_FILE} could not be read: ${error.message}`)
  }
  let parsed
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    throw new Error(`${EXCEPTIONS_FILE} is not valid JSON: ${error.message}`)
  }
  if (!isPlainObject(parsed)) {
    throw new Error(`${EXCEPTIONS_FILE} must contain a JSON object`)
  }
  if (parsed.npmAdvisories === undefined) {
    throw new Error(`${EXCEPTIONS_FILE} has no npmAdvisories key — use an empty array to declare no exceptions`)
  }
  return parsed.npmAdvisories
}

// Note there is deliberately no `--today` flag: a CLI switch that can make an
// expired exception look valid would be an override in the unsafe direction on
// a security gate. Expiry is only ever judged against the real clock here, and
// is fully covered through `evaluateAudit()` in the tests.
function parseArgs(argv) {
  const options = { source: undefined, exceptions: undefined }
  const positional = []
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    if (arg === '--exceptions') {
      const value = argv[index + 1]
      if (value === undefined) throw new Error(`${arg} requires a value`)
      options.exceptions = value
      index += 1
      continue
    }
    positional.push(arg)
  }
  if (positional.length > 1) throw new Error('expected at most one audit-JSON path (use "-" for stdin)')
  options.source = positional[0]
  return options
}

async function main(argv) {
  const options = parseArgs(argv)
  const root = path.resolve(import.meta.dirname, '..')
  // `--exceptions none` is a test affordance: evaluate with an empty registry.
  const exceptions = options.exceptions === 'none'
    ? []
    : await loadExceptions(options.exceptions ?? path.join(root, 'supply-chain', 'exceptions.json'))
  const audit = await loadAuditJson(options.source)
  const today = new Date().toISOString().slice(0, 10)

  const result = evaluateAudit({ audit, exceptions, today })
  if (!result.ok) {
    console.error(result.errors.join('\n'))
    for (const warning of result.warnings) {
      console.error(`warning: ${warning}`)
    }
    if (result.blocking.length > 0) {
      console.error(`\nDependency-audit gate FAILED: ${result.blocking.length} unexcepted high/critical advisor${result.blocking.length === 1 ? 'y' : 'ies'}.`)
      console.error(`Patch it via an override in pnpm-workspace.yaml, or — only while no patched release exists — add an entry to ${EXCEPTIONS_FILE}.`)
    } else {
      // No blocking advisory, but something above was still wrong: unusable
      // audit data or an invalid exception. Fail closed and say which.
      console.error('\nDependency-audit gate FAILED: the audit data or the exception registry could not be trusted.')
      console.error('This is a fail-closed result, not a clean audit — fix the input above and re-run.')
    }
    process.exitCode = 1
    return
  }
  for (const warning of result.warnings) {
    console.warn(`warning: ${warning}`)
  }
  for (const advisory of result.excepted) {
    console.log(`excepted: ${advisory.id} (${advisory.module}) until ${advisory.exception.expires} — ${advisory.exception.reason} [owner ${advisory.exception.owner}]`)
  }
  console.log(`Dependency-audit gate passed: no unexcepted high or critical advisories (${result.excepted.length} excepted).`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    await main(process.argv.slice(2))
  } catch (error) {
    console.error(error.message)
    process.exitCode = 1
  }
}
