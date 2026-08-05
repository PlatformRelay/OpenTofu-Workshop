#!/usr/bin/env node
// Paper gate: lab-contract CI must run the zero-dep script via node, not pnpm.
// Regression for exit 127 when the job had setup-node only and called `pnpm lab:contract`.
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function labContractJob(workflow) {
  const marker = '  lab-contract:\n'
  const start = workflow.indexOf(marker)
  assert.ok(start >= 0, 'ci.yml must define a lab-contract job')
  const rest = workflow.slice(start)
  const next = rest.search(/\n  [a-z0-9-]+:\n/)
  return next === -1 ? rest : rest.slice(0, next)
}

test('lab-contract CI job runs node scripts/lab-contract.mjs without pnpm', () => {
  const wf = readFileSync(resolve(ROOT, '.github/workflows/ci.yml'), 'utf8')
  const job = labContractJob(wf)

  assert.match(job, /node scripts\/lab-contract\.mjs/)
  assert.doesNotMatch(job, /^\s+- run:.*\bpnpm\b/m)
  assert.doesNotMatch(job, /uses:\s*pnpm\/action-setup/)
})

test('lab-contract CI job runs its paper gate via node --test', () => {
  const wf = readFileSync(resolve(ROOT, '.github/workflows/ci.yml'), 'utf8')
  const job = labContractJob(wf)

  assert.match(job, /node --test scripts\/lab-contract-ci\.test\.mjs/)
})
