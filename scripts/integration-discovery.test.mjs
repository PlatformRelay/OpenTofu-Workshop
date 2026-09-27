// Regression guard for the integration lanes (CI verify-integration and
// Taskfile verify:integration:tests). Both run scripts/integration-tests.sh;
// this test executes each lane's OWN command text against a scratch tree with a
// stub `tofu` and asserts that the lane:
//   - derives the `tofu test` filter from the files it discovers, so an added
//     integration_extra.tftest.hcl runs (a hardcoded filter skipped it);
//   - fails when a non-final file fails (a loop returning only its last
//     command's status swallowed it);
//   - fails when a filter ran zero tests — `tofu test -filter=<no match>`
//     prints "Success! 0 passed, 0 failed." and exits 0;
//   - fails when it discovers no integration roots at all;
//   - runs the participant's plain `tofu init` (no -backend=false) with
//     TF_VAR_state_passphrase set, so the encrypted roots' init path is covered;
//   - runs in a scratch copy of each root, never in the checkout, so a learner's
//     hello.txt / bucket in labs/day-1/00-setup is not clobbered.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  readFileSync,
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  chmodSync,
  rmSync,
  symlinkSync,
  existsSync,
  realpathSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'
import { parse } from 'yaml'

const root = new URL('..', import.meta.url)
const repo = fileURLToPath(root)
const taskfile = readFileSync(new URL('Taskfile.yaml', root), 'utf8')
const ci = parse(readFileSync(new URL('.github/workflows/ci.yml', root), 'utf8'))

const taskScript = parse(taskfile)
  .tasks['verify:integration:tests'].cmds[0]
  .replaceAll('{{.LOCALSTACK_URL}}', 'http://localhost:4566')

// The CI lane's own run script, taken from the parsed workflow rather than a
// substring of its source, so a dead or commented-out step cannot satisfy this.
const ciStep = ci.jobs['verify-integration'].steps.find(
  (s) => s.name === 'Integration tests against LocalStack',
)
const ciScript = ciStep.run

const lanes = [
  ['Taskfile', taskScript],
  ['CI', ciScript],
]

// Build a scratch checkout with an extra integration file and a stub `tofu`
// that records every call. `opts.fail` names a directory + filter for which the
// stub exits 1; `opts.zero` names a filter for which it reports 0 passed;
// `opts.empty` builds a tree with no integration roots at all.
function scratchTree(opts = {}) {
  const scratch = mkdtempSync(join(tmpdir(), 'itest-discovery-'))
  const log = join(scratch, 'calls.log')
  const bin = join(scratch, 'bin')
  mkdirSync(bin)
  // The lanes call scripts/integration-tests.sh relative to the checkout.
  symlinkSync(join(repo, 'scripts'), join(scratch, 'scripts'))
  mkdirSync(join(scratch, 'modules'))
  if (!opts.empty) {
    for (const d of ['examples/app', 'labs/day-1/app', 'labs/day-2/app']) {
      mkdirSync(join(scratch, d, 'tests'), { recursive: true })
      writeFileSync(join(scratch, d, 'tests', 'integration.tftest.hcl'), '# base\n')
      writeFileSync(join(scratch, d, 'main.tf'), '# root\n')
    }
    // The file that a hardcoded filter would skip.
    writeFileSync(
      join(scratch, 'labs/day-1/app/tests', 'integration_extra.tftest.hcl'),
      '# extra\n',
    )
  } else {
    mkdirSync(join(scratch, 'examples/app/tests'), { recursive: true })
    writeFileSync(join(scratch, 'examples/app/tests', 'unit.tftest.hcl'), '# unit only\n')
  }

  // A marker file, not $PWD: bash inherits PWD from the parent process. The
  // lane copies the root, so the marker travels with it.
  if (opts.fail) writeFileSync(join(scratch, opts.fail.dir, 'FAIL_INTEGRATION'), '')
  writeFileSync(
    join(bin, 'tofu'),
    `#!/usr/bin/env bash
printf '%s|%s|%s\\n' "$(pwd -P)" "\${TF_VAR_state_passphrase:-<unset>}" "$*" >> "${log}"
case "$1" in
  test)
    # Like a real apply writing path.module/hello.txt.
    echo clobbered > hello.txt
    if [ "$2" = "${opts.fail?.filter ?? ''}" ] && [ -f FAIL_INTEGRATION ]; then
      echo "Failure! 0 passed, 1 failed."; exit 1
    fi
    if [ "$2" = "${opts.zero ?? ''}" ]; then
      printf 'Warning: No tests were found\\nSuccess! 0 passed, 0 failed.\\n'; exit 0
    fi
    echo "Success! 1 passed, 0 failed."
    ;;
esac
exit 0
`,
  )
  chmodSync(join(bin, 'tofu'), 0o755)
  // The CI retry sleeps between attempts; a no-op keeps a failing case fast.
  writeFileSync(join(bin, 'sleep'), '#!/usr/bin/env bash\nexit 0\n')
  chmodSync(join(bin, 'sleep'), 0o755)
  return { scratch, log, bin }
}

function runLane(script, opts) {
  const tree = scratchTree(opts)
  const exec = () =>
    execFileSync('bash', ['-c', script], {
      cwd: tree.scratch,
      env: {
        ...process.env,
        PATH: `${tree.bin}:${process.env.PATH}`,
        TF_VAR_state_passphrase: '',
      },
      stdio: 'pipe',
    })
  const calls = () =>
    existsSync(tree.log)
      ? readFileSync(tree.log, 'utf8').trim().split('\n').filter(Boolean).map((line) => {
        const [cwd, passphrase, args] = line.split('|')
        return { cwd, passphrase, args }
      })
      : []
  return { ...tree, exec, calls }
}

const discovered = [
  'test -filter=tests/integration.tftest.hcl -no-color',
  'test -filter=tests/integration.tftest.hcl -no-color',
  'test -filter=tests/integration.tftest.hcl -no-color',
  'test -filter=tests/integration_extra.tftest.hcl -no-color',
].sort()

const testCalls = (calls) => calls.filter((c) => c.args.startsWith('test ')).map((c) => c.args).sort()

for (const [lane, script] of lanes) {
  test(`${lane} lane runs scripts/integration-tests.sh`, () => {
    assert.match(script, /(^|\n)\s*bash scripts\/integration-tests\.sh\b/)
  })

  test(`${lane} integration lane runs every discovered integration file`, () => {
    const t = runLane(script)
    try {
      t.exec()
      assert.deepEqual(testCalls(t.calls()), discovered)
    } finally {
      rmSync(t.scratch, { recursive: true, force: true })
    }
  })

  test(`${lane} integration lane fails when a non-final file fails`, () => {
    const t = runLane(script, {
      fail: { dir: 'labs/day-1/app', filter: '-filter=tests/integration.tftest.hcl' },
    })
    try {
      assert.throws(t.exec, 'a non-final failure must fail the lane')
      assert.ok(
        testCalls(t.calls()).includes('test -filter=tests/integration_extra.tftest.hcl -no-color'),
        'the loop must reach the passing file after the failing one',
      )
    } finally {
      rmSync(t.scratch, { recursive: true, force: true })
    }
  })

  test(`${lane} integration lane fails when a filter ran zero tests`, () => {
    const t = runLane(script, { zero: '-filter=tests/integration_extra.tftest.hcl' })
    try {
      assert.throws(t.exec, /0 passed|ran no tests/, 'a vacuous "0 passed" must fail the lane')
    } finally {
      rmSync(t.scratch, { recursive: true, force: true })
    }
  })

  test(`${lane} integration lane fails when no integration roots are discovered`, () => {
    const t = runLane(script, { empty: true })
    try {
      assert.throws(t.exec, /no integration/i)
    } finally {
      rmSync(t.scratch, { recursive: true, force: true })
    }
  })

  test(`${lane} integration lane runs the participant's plain tofu init with a passphrase`, () => {
    const t = runLane(script)
    try {
      t.exec()
      const inits = t.calls().filter((c) => c.args.startsWith('init'))
      assert.equal(inits.length, 3, 'one init per root')
      for (const init of inits) {
        assert.doesNotMatch(init.args, /-backend=false/, 'the participant path is a plain tofu init')
        assert.notEqual(init.passphrase, '<unset>')
        assert.ok(init.passphrase.length >= 16, 'PBKDF2 needs a >= 16 char passphrase')
      }
    } finally {
      rmSync(t.scratch, { recursive: true, force: true })
    }
  })

  test(`${lane} integration lane never runs tofu inside the checkout`, () => {
    const t = runLane(script)
    try {
      t.exec()
      const checkout = realpathSync(t.scratch)
      for (const call of t.calls()) {
        assert.ok(!call.cwd.startsWith(checkout + '/'), `tofu ran in the checkout: ${call.cwd}`)
      }
      for (const d of ['examples/app', 'labs/day-1/app', 'labs/day-2/app']) {
        assert.ok(!existsSync(join(t.scratch, d, 'hello.txt')), `${d}/hello.txt was clobbered`)
      }
    } finally {
      rmSync(t.scratch, { recursive: true, force: true })
    }
  })
}
