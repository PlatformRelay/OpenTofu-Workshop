#!/usr/bin/env node
// Paper gate: lab-contract CI must run the zero-dep script via node, not pnpm.
// Regression for exit 127 when the job had setup-node only and called `pnpm lab:contract`.
// Also the mutation gate for the workdirHazards layer check (audit REL-3): recovery
// blocks must not cd into nonexistent lab dirs or rm a git-tracked .terraform.lock.hcl.
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
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
import { auditVariantLabs, workdirHazards } from './lab-contract.mjs'

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

// A repo-root-anchored cd works whether a learner runs blocks from the root or
// in order from wherever the previous block left them, so the guard resolves
// it (as the repo root) instead of giving up on the rest of the block.
test('workdirHazards resolves a git-toplevel-anchored cd and still reds on a bad target', () => {
  const broken = fence('cd "$(git rev-parse --show-toplevel)/labs/day-9/no-such-lab"')
  assert.deepEqual(workdirHazards(broken),
    ['line 2: cd into nonexistent directory: labs/day-9/no-such-lab'])
})

test('workdirHazards keeps judging after a git-toplevel-anchored cd', () => {
  const block = fence([
    'cd "$(git rev-parse --show-toplevel)/examples"',
    'cd capstone',
    'rm -f .terraform.lock.hcl',
  ].join('\n'))
  const errors = workdirHazards(block)
  assert.ok(errors.some((e) => /rm of git-tracked lockfile: examples\/capstone\/\.terraform\.lock\.hcl/.test(e)),
    `expected tracked-lockfile error, got: ${JSON.stringify(errors)}`)
})

test('workdirHazards accepts a bare git-toplevel cd as the repo root', () => {
  const block = fence([
    'cd "$(git rev-parse --show-toplevel)"',
    'cd examples/capstone',
  ].join('\n'))
  assert.deepEqual(workdirHazards(block), [])
})

test('the live capstone and naming-labels solutions carry no workdir hazards', () => {
  for (const file of ['labs/day-3/26-capstone.solution.md', 'labs/day-1/08-naming-labels.solution.md']) {
    assert.deepEqual(workdirHazards(readFileSync(resolve(ROOT, file), 'utf8')), [], file)
  }
})

// --- OVH-variant sibling-solution contract ------------------------------------
// The variant's participant labs live outside the base discovery scope, so the
// base contract never sees them. This pass enforces the sibling-solution rule
// (or an explicit thin-delta marker) for variant/ovh/labs/**.
function variantRoot() {
  const root = mkdtempSync(join(tmpdir(), 'ot-variant-contract-'))
  mkdirSync(join(root, 'variant/ovh/labs/day-1/00-setup'), { recursive: true })
  return root
}

test('auditVariantLabs is a no-op on a base-only checkout', () => {
  const root = mkdtempSync(join(tmpdir(), 'ot-variant-contract-'))
  assert.deepEqual(auditVariantLabs(root), [])
})

test('auditVariantLabs reds on a variant lab README with no sibling solution', () => {
  const root = variantRoot()
  writeFileSync(join(root, 'variant/ovh/labs/day-1/00-setup/README.md'), '# OVH twin\n')
  const errors = auditVariantLabs(root)
  assert.ok(errors.some((e) => /missing sibling README\.solution\.md/.test(e)),
    `expected sibling-solution error, got: ${JSON.stringify(errors)}`)
})

test('auditVariantLabs passes when the sibling solution exists', () => {
  const root = variantRoot()
  const dir = join(root, 'variant/ovh/labs/day-1/00-setup')
  writeFileSync(join(dir, 'README.md'), '# OVH twin\n')
  writeFileSync(join(dir, 'README.solution.md'), '# Solution\n')
  assert.deepEqual(auditVariantLabs(root), [])
})

test('auditVariantLabs passes a thin-delta twin with the explicit marker', () => {
  const root = variantRoot()
  writeFileSync(
    join(root, 'variant/ovh/labs/day-1/00-setup/README.md'),
    '# OVH twin\n\n<!-- variant-solution: base -->\nBase solution applies.\n',
  )
  assert.deepEqual(auditVariantLabs(root), [])
})

test('auditVariantLabs covers the OVH-native bootstrap lab', () => {
  const root = mkdtempSync(join(tmpdir(), 'ot-variant-contract-'))
  mkdirSync(join(root, 'variant/ovh/bootstrap'), { recursive: true })
  writeFileSync(join(root, 'variant/ovh/bootstrap/README.md'), '# Bootstrap lab\n')
  const errors = auditVariantLabs(root)
  assert.ok(errors.some((e) => /variant\/ovh\/bootstrap\/README\.md: missing sibling README\.solution\.md/.test(e)),
    `expected bootstrap sibling-solution error, got: ${JSON.stringify(errors)}`)
})

test('auditVariantLabs passes the bootstrap lab once its solution exists', () => {
  const root = mkdtempSync(join(tmpdir(), 'ot-variant-contract-'))
  mkdirSync(join(root, 'variant/ovh/bootstrap'), { recursive: true })
  writeFileSync(join(root, 'variant/ovh/bootstrap/README.md'), '# Bootstrap lab\n')
  writeFileSync(join(root, 'variant/ovh/bootstrap/README.solution.md'), '# Solution\n')
  assert.deepEqual(auditVariantLabs(root), [])
})

test('auditVariantLabs ignores .terraform provider-cache READMEs', () => {
  const root = variantRoot()
  // A lived-in checkout carries vendored READMEs under variant/**/.terraform;
  // they are not variant labs and must not red the sibling-solution rule.
  mkdirSync(join(root, 'variant/ovh/labs/day-1/00-setup/.terraform/providers/vendor'), { recursive: true })
  writeFileSync(
    join(root, 'variant/ovh/labs/day-1/00-setup/.terraform/providers/vendor/README.md'),
    '# vendored provider\n',
  )
  assert.deepEqual(auditVariantLabs(root), [])
})

test('auditVariantLabs reuses the workdir layer guard on variant READMEs', () => {
  const root = variantRoot()
  writeFileSync(
    join(root, 'variant/ovh/labs/day-1/00-setup/README.md'),
    '# OVH twin\n\n<!-- variant-solution: base -->\n```bash\ncd variant/ovh/nope\n```\n',
  )
  const errors = auditVariantLabs(root)
  assert.ok(errors.some((e) => /cd into nonexistent directory: variant\/ovh\/nope/.test(e)),
    `expected workdir hazard, got: ${JSON.stringify(errors)}`)
})
