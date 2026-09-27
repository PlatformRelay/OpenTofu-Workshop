#!/usr/bin/env node
// Semantic CI-wiring contract for the OVH variant lane.
//
// The variant's only CI coverage is the verify-ovh-unit job and the go-vet
// matrix entries for its Go modules. Deleting either would leave every other
// job green while variant/ovh/** silently loses its compile/unit gate. This
// parses ci.yml into a model and asserts the executable wiring, so a prose
// mention or a behavior-preserving YAML reflow cannot certify the gate.
//
// The go-vet matrix is checked against the Go modules DISCOVERED in the tree
// (tracked go.mod files), not a hardcoded list: a new variant (or lab) module
// with no matrix entry reds here instead of going uncompiled.
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'
import { parse as parseYaml } from 'yaml'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function jobs() {
  const workflow = parseYaml(readFileSync(resolve(ROOT, '.github/workflows/ci.yml'), 'utf8'))
  return workflow?.jobs ?? {}
}

function runCommands(job) {
  return (job?.steps ?? [])
    .map((step) => step?.run)
    .filter((run) => typeof run === 'string')
    .join('\n')
}

// Directories (repo-relative, POSIX) holding a go.mod. Prefers the git index so
// a learner's untracked scratch module cannot red the check; falls back to a
// filesystem walk (skipping dot-dirs and node_modules) where there is no index.
export function goModuleDirs(root = ROOT) {
  let files = null
  if (existsSync(join(root, '.git'))) {
    try {
      files = execFileSync('git', ['-C', root, 'ls-files', '--', ':(glob)**/go.mod', 'go.mod'], {
        encoding: 'utf8',
      })
        .split('\n')
        .filter(Boolean)
    } catch {
      files = null
    }
  }
  if (files === null) {
    files = []
    const walk = (dir) => {
      for (const entry of readdirSync(dir, { withFileTypes: true })) {
        if (entry.name.startsWith('.') || entry.name === 'node_modules') continue
        const abs = join(dir, entry.name)
        if (entry.isDirectory()) walk(abs)
        else if (entry.name === 'go.mod') files.push(relative(root, abs).split('\\').join('/'))
      }
    }
    walk(root)
  }
  return [...new Set(files.map((f) => (f.includes('/') ? f.slice(0, f.lastIndexOf('/')) : '.')))].sort()
}

// Every discovered module must be in the matrix, and every matrix entry must
// still be a module (a stale entry would fail CI at checkout-time anyway, but
// naming it here is clearer).
export function matrixProblems(moduleDirs, matrixDirs) {
  const matrix = new Set(matrixDirs ?? [])
  const modules = new Set(moduleDirs)
  const problems = []
  for (const d of modules) if (!matrix.has(d)) problems.push(`go module ${d} has no go-vet matrix entry`)
  for (const d of matrix) if (!modules.has(d)) problems.push(`go-vet matrix entry ${d} has no go.mod`)
  return problems
}

test('ci.yml runs the OVH variant unit lane', () => {
  const job = jobs()['verify-ovh-unit']
  assert.ok(job, 'ci.yml must define the verify-ovh-unit job')
  const runs = runCommands(job)
  assert.match(runs, /bash variant\/ovh\/scripts\/verify-selftest\.sh/)
  assert.match(runs, /bash variant\/ovh\/scripts\/verify\.sh/)
})

// verify.sh's pin check only greps ci.yml for ONE matching literal, so a second
// job pinned to a different OpenTofu would slip past it. Pin this job exactly.
test('verify-ovh-unit pins OpenTofu to versions.env TOFU_VERSION', () => {
  const pin = readFileSync(resolve(ROOT, 'versions.env'), 'utf8').match(/^TOFU_VERSION=(\S+)$/m)?.[1]
  assert.ok(pin, 'versions.env must define TOFU_VERSION')
  const setup = (jobs()['verify-ovh-unit']?.steps ?? []).find((step) =>
    String(step?.uses ?? '').startsWith('opentofu/setup-opentofu@'))
  assert.ok(setup, 'verify-ovh-unit must install OpenTofu with opentofu/setup-opentofu')
  assert.equal(String(setup.with?.tofu_version), pin)
})

test('the tree has at least one variant Go module (discovery is not vacuous)', () => {
  const dirs = goModuleDirs()
  assert.ok(dirs.some((d) => d.startsWith('variant/')), `no variant go.mod discovered: ${JSON.stringify(dirs)}`)
})

test('ci.yml go-vet matrix compiles every discovered Go module', () => {
  const job = jobs()['go-vet']
  assert.ok(job, 'ci.yml must define the go-vet job')
  assert.deepEqual(matrixProblems(goModuleDirs(), job.strategy?.matrix?.dir), [])

  // The gate itself, run once per matrix dir, with the toolchain pinned by
  // each module's own go.mod rather than a ci.yml literal.
  const runs = runCommands(job)
  assert.match(runs, /go vet \.\/\.\.\./)
  const setup = (job.steps ?? []).find((step) => step?.with?.['go-version-file'])
  assert.equal(setup?.with?.['go-version-file'], '${{ matrix.dir }}/go.mod')
})

test('matrixProblems reds on a discovered variant module missing from the matrix', () => {
  const root = mkdtempSync(join(tmpdir(), 'ot-ci-wiring-'))
  for (const d of ['labs/day-2/a', 'variant/ovh/labs/b', 'variant/other/c']) {
    mkdirSync(join(root, d), { recursive: true })
    writeFileSync(join(root, d, 'go.mod'), 'module example.com/x\n')
  }
  mkdirSync(join(root, '.cache/d'), { recursive: true })
  writeFileSync(join(root, '.cache/d/go.mod'), 'module example.com/ignored\n')
  const dirs = goModuleDirs(root)
  assert.deepEqual(dirs, ['labs/day-2/a', 'variant/other/c', 'variant/ovh/labs/b'])
  assert.deepEqual(matrixProblems(dirs, ['labs/day-2/a', 'variant/ovh/labs/b', 'labs/gone']), [
    'go module variant/other/c has no go-vet matrix entry',
    'go-vet matrix entry labs/gone has no go.mod',
  ])
})
