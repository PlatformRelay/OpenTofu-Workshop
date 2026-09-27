// Semantic contract for Taskfile.yaml's setup ordering and verify-lock
// preconditions. go-task is not installed in CI's verify-unit job, so rather
// than grep the Taskfile text — which a behavior-preserving reformat can defeat
// and a wrong-but-similar file can satisfy — parse it into a normalized model
// and assert the dependency graph and precondition wiring go-task would act on,
// then execute each guard command to confirm its refusal behavior.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, mkdtempSync, mkdirSync, rmSync, writeFileSync, chmodSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawnSync } from 'node:child_process'
import { parse } from 'yaml'

const root = new URL('..', import.meta.url)
const tasks = parse(readFileSync(new URL('Taskfile.yaml', root), 'utf8')).tasks

const preconditionsOf = (name) =>
  (tasks[name].preconditions ?? []).map((p) =>
    typeof p === 'string' ? { sh: p } : p,
  )

test('task setup runs bootstrap before pnpm install', () => {
  assert.ok(
    tasks['setup'].deps.includes('setup:preflight'),
    'setup must depend on setup:preflight',
  )
  assert.ok(
    tasks['setup'].deps.includes('setup:pnpm'),
    'setup must depend on setup:pnpm',
  )
  assert.deepEqual(
    tasks['setup:pnpm'].deps,
    ['setup:preflight'],
    'setup:pnpm must depend on setup:preflight',
  )
  assert.ok(
    !preconditionsOf('setup').some((p) => /\bpnpm\b/.test(p.sh)),
    'setup must not gate on pnpm before bootstrap installs it',
  )
})

test('setup:preflight runs once and never under BOOTSTRAP_STRICT', () => {
  // `task setup` reaches setup:preflight twice (directly and via setup:pnpm);
  // without run: once go-task would run bootstrap twice.
  assert.equal(tasks['setup:preflight'].run, 'once', 'setup:preflight must be run: once')
  // A BOOTSTRAP_STRICT=1 left in the shell must not turn a missing LocalStack
  // route or Day-2/3 tool into rc 3 and so skip `pnpm install`.
  // Pinned on the command line: go-task lets an exported OS variable override
  // a task-level `env:`, so `env: {BOOTSTRAP_STRICT: '0'}` would not hold.
  assert.deepEqual(
    tasks['setup:preflight'].cmds,
    ['BOOTSTRAP_STRICT=0 bash setup/bootstrap.sh'],
    'setup:preflight must pin BOOTSTRAP_STRICT=0 so strict readiness never blocks pnpm install',
  )
})

test('preflight:strict is the strict readiness check the runbook calls', () => {
  const strict = tasks['preflight:strict']
  assert.ok(strict, 'Taskfile must define preflight:strict')
  assert.deepEqual(strict.cmds, ['BOOTSTRAP_STRICT=1 bash setup/bootstrap.sh'])
  assert.ok(!strict.deps?.includes('setup:pnpm'), 'a readiness check must not install anything')
  const runbook = readFileSync(new URL('docs/facilitator-runbook.md', root), 'utf8')
  assert.match(runbook, /task preflight:strict/, 'the facilitator runbook must run the strict check')
})

test('lab init/plan/apply/validate refuse while a verify lock is present', () => {
  const scratch = mkdtempSync(join(tmpdir(), 'taskfile-lock-'))
  try {
    for (const name of ['lab:init', 'lab:plan', 'lab:apply', 'lab:validate']) {
      const lock = preconditionsOf(name).find((p) =>
        p.sh.includes('.verify.lock'),
      )
      assert.ok(lock, `${name} must carry a .verify.lock precondition`)
      assert.match(
        lock.msg,
        /verify\.sh is running/,
        `${name} must explain the refusal`,
      )
      // The ABSOLUTE lock path (a relative `rm -rf .verify.lock` typed from a
      // lab workdir removes nothing) and how to tell a stale lock: verify.sh's
      // own liveness test is `ps -p <pid>` on the pid it records.
      assert.ok(
        lock.msg.includes('{{.ROOT_DIR}}/.verify.lock'),
        `${name} must print the absolute lock path`,
      )
      assert.match(lock.msg, /ps -p/, `${name} must say how to tell a stale lock`)
      assert.match(lock.msg, /\.verify\.lock\/pid/, `${name} must point at the recorded pid`)
      // Execute the guard the way go-task's `sh:` precondition does: run it
      // from the checkout root and read its exit status. No lock → 0.
      execFileSync('bash', ['-c', lock.sh], { cwd: scratch })
      mkdirSync(join(scratch, '.verify.lock'), { recursive: true })
      assert.throws(
        () => execFileSync('bash', ['-c', lock.sh], { cwd: scratch }),
        `${name} must refuse while .verify.lock exists`,
      )
      rmSync(join(scratch, '.verify.lock'), { recursive: true, force: true })
    }
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
})

test('lab:up:k8s refuses an empty kube context and proceeds only on an explicit match', () => {
  const block = tasks['lab:up:k8s'].cmds[0]
  const repo = fileURLToPath(root)
  const scratch = mkdtempSync(join(tmpdir(), 'taskfile-kube-'))
  const bin = join(scratch, 'bin')
  mkdirSync(bin, { recursive: true })
  const stub = join(bin, 'kubectl')
  const run = (env) =>
    spawnSync('bash', ['-c', block], {
      cwd: repo,
      env: { ...process.env, ...env },
      encoding: 'utf8',
    })
  try {
    // No context (current-context fails): an unset ALLOW_KUBE_CONTEXT must NOT
    // be treated as a match, and the non-interactive confirm must abort.
    writeFileSync(stub, '#!/bin/sh\ncase "$*" in *current-context*) exit 1;; esac\nexit 0\n')
    chmodSync(stub, 0o755)
    const negative = run({ PATH: `${bin}:${process.env.PATH}` })
    assert.notEqual(negative.status, 0, 'empty context must abort non-interactively')
    assert.doesNotMatch(negative.stdout, /matches — proceeding/)

    // An explicit match proceeds without the confirm prompt.
    writeFileSync(stub, '#!/bin/sh\ncase "$*" in *current-context*) echo kind-opentofu;; esac\nexit 0\n')
    chmodSync(stub, 0o755)
    const positive = run({
      PATH: `${bin}:${process.env.PATH}`,
      ALLOW_KUBE_CONTEXT: 'kind-opentofu',
    })
    assert.equal(positive.status, 0)
    assert.match(positive.stdout, /matches — proceeding/)
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
})
