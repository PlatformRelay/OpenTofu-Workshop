#!/usr/bin/env node
// Paper gate: lab-contract CI must run the zero-dep script via node, not pnpm.
// Regression for exit 127 when the job had setup-node only and called `pnpm lab:contract`.
// Also the mutation gate for the workdirHazards layer check (audit REL-3): recovery
// blocks must not cd into nonexistent lab dirs or rm a git-tracked .terraform.lock.hcl.
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

// --- workdirHazards layer gate (audit REL-3) -------------------------------
// The day-2 lockfile deletion was fixed per-outcome and the class recurred in
// the day-3 capstone solution. These mutations pin the LAYER: any lab/solution
// block that cds into a nonexistent dir or rms a tracked lockfile must red.
import { workdirHazards } from './lab-contract.mjs'

const fence = (body) => '```bash\n' + body + '\n```\n'

test('workdirHazards reds on the historical broken capstone recovery block', () => {
  const broken = fence([
    'cd labs/day-3/26-capstone',
    'tofu destroy -auto-approve || true',
    'rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.*',
    'cd ../../..',
  ].join('\n'))
  const errors = workdirHazards(broken)
  assert.ok(errors.some((e) => /cd into nonexistent directory: labs\/day-3\/26-capstone/.test(e)),
    `expected nonexistent-cd error, got: ${JSON.stringify(errors)}`)
})

test('workdirHazards reds on rm of a tracked lockfile reached via cd', () => {
  const broken = fence([
    'cd examples/capstone',
    'rm -rf .terraform .terraform.lock.hcl terraform.tfstate',
  ].join('\n'))
  const errors = workdirHazards(broken)
  assert.ok(errors.some((e) => /rm of git-tracked lockfile: examples\/capstone\/\.terraform\.lock\.hcl/.test(e)),
    `expected tracked-lockfile error, got: ${JSON.stringify(errors)}`)
})

test('workdirHazards reds on rm of an explicit tracked lockfile path', () => {
  const errors = workdirHazards(fence('rm -f examples/capstone/.terraform.lock.hcl'))
  assert.deepEqual(errors, ['line 2: rm of git-tracked lockfile: examples/capstone/.terraform.lock.hcl'])
})

test('workdirHazards stays green on the corrected -chdir house style', () => {
  const fixed = fence([
    'tofu -chdir=examples/capstone destroy -auto-approve -no-color || true',
    'rm -rf examples/capstone/.terraform',
    'rm -f examples/capstone/*.tfstate examples/capstone/*.tfstate.*',
  ].join('\n'))
  assert.deepEqual(workdirHazards(fixed), [])
})

test('workdirHazards stays green on untracked lockfile resets in real lab dirs', () => {
  const dayOne = fence([
    'cd labs/day-1/04-state',
    'rm -rf .terraform .terraform.lock.hcl state out main.tf.bak',
    'cd ../../..',
  ].join('\n'))
  assert.deepEqual(workdirHazards(dayOne), [])
})

test('workdirHazards does not guess after a variable cd', () => {
  const varCd = fence([
    'cd "$demo"',
    'rm -rf .terraform.lock.hcl',
    'cd "$OLDPWD" 2>/dev/null || true',
  ].join('\n'))
  assert.deepEqual(workdirHazards(varCd), [])
})

test('the live capstone and naming-labels solutions carry no workdir hazards', () => {
  for (const file of ['labs/day-3/26-capstone.solution.md', 'labs/day-1/08-naming-labels.solution.md']) {
    assert.deepEqual(workdirHazards(readFileSync(resolve(ROOT, file), 'utf8')), [], file)
  }
})
