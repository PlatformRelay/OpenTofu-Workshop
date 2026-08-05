import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

import { checkSupplyChainPolicy } from './supply-chain-policy.mjs'

async function fixture(files) {
  const root = await mkdtemp(path.join(tmpdir(), 'otw-supply-policy-'))
  await Promise.all(Object.entries(files).map(async ([name, contents]) => {
    const target = path.join(root, name)
    await mkdir(path.dirname(target), { recursive: true })
    await writeFile(target, contents)
  }))
  return root
}

test('rejects mutable action references', async () => {
  const root = await fixture({
    '.github/workflows/ci.yml': 'steps:\n  - uses: actions/checkout@v4\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('immutable 40-character commit SHA')))
})

test('requires a human-readable version comment beside an action SHA', async () => {
  const root = await fixture({
    '.github/workflows/ci.yml': `steps:\n  - uses: actions/checkout@${'a'.repeat(40)}\n`,
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('version comment')))
})

test('accepts pinned actions and local actions', async () => {
  const root = await fixture({
    '.github/workflows/ci.yml': `permissions:\n  contents: read\nsteps:\n  - uses: actions/checkout@${'a'.repeat(40)} # v4.2.2\n  - uses: ./actions/local\n`,
  })

  const result = await checkSupplyChainPolicy(root)

  assert.deepEqual(result.errors, [])
})

test('rejects unverified remote execution in maintained shell surfaces', async () => {
  const root = await fixture({
    'setup/bootstrap.sh': 'curl -fsSL https://example.com/install.sh | sh\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('unverified remote execution')))
})

test('rejects expired remote execution exceptions', async () => {
  const root = await fixture({
    'setup/bootstrap.sh': '# supply-chain-exception: bootstrap-install\ncurl -fsSL https://example.com/install.sh | sh\n',
    'supply-chain/exceptions.json': JSON.stringify({
      remoteInputs: [{
        id: 'bootstrap-install',
        source: 'https://example.com/install.sh',
        kind: 'accepted-risk',
        command: 'curl -fsSL https://example.com/install.sh | sh',
        reason: 'Temporary exception.',
        expires: '2026-08-02',
      }],
    }),
  })

  const result = await checkSupplyChainPolicy(root, { today: '2026-08-03' })

  assert.ok(result.errors.some((error) => error.includes('expired')))
})

test('rejects workflow-wide write permissions', async () => {
  const root = await fixture({
    '.github/workflows/ci.yml': 'permissions:\n  contents: write\njobs: {}\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('workflow-wide write permission')))
})

test('rejects unnecessary job-level write permissions', async () => {
  const root = await fixture({
    '.github/workflows/ci.yml': 'permissions:\n  contents: read\njobs:\n  test:\n    permissions:\n      contents: read\n      issues: write\n    steps: []\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('job-level write permission issues:write is not allowed')))
})

test('allows Pages deploy job to write pages and id-token', async () => {
  const root = await fixture({
    '.github/workflows/pages.yml': `permissions:
  contents: read
jobs:
  deploy:
    permissions:
      pages: write
      id-token: write
    steps:
      - uses: actions/deploy-pages@${'a'.repeat(40)} # v4
`,
  })

  const result = await checkSupplyChainPolicy(root)

  assert.deepEqual(result.errors, [])
})

test('allows release publish job to write contents', async () => {
  const root = await fixture({
    '.github/workflows/release.yml': `permissions:
  contents: read
jobs:
  publish:
    permissions:
      contents: write
    steps:
      - uses: softprops/action-gh-release@${'a'.repeat(40)} # v2
`,
  })

  const result = await checkSupplyChainPolicy(root)

  assert.deepEqual(result.errors, [])
})

test('repository workflows and setup surfaces pass supply-chain policy', async () => {
  const repositoryRoot = path.resolve(import.meta.dirname, '..')
  const result = await checkSupplyChainPolicy(repositoryRoot)
  assert.deepEqual(result.errors, result.errors.filter(() => true))
  assert.deepEqual(result.errors, [])
})

test('CI supply-chain job raises the Node heap for policy steps', async () => {
  const workflow = await readFile(
    path.join(import.meta.dirname, '..', '.github/workflows/ci.yml'),
    'utf8',
  )
  assert.match(
    workflow,
    /supply-chain:[\s\S]*?NODE_OPTIONS:\s*--max-old-space-size=\d+/,
  )
})
