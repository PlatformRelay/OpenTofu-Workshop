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

test('rejects mutable container action images', async () => {
  const root = await fixture({
    '.github/workflows/ci.yml': 'steps:\n  - uses: docker://alpine:3.23\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('container action must use an immutable sha256 digest')))
})

test('rejects unverified remote execution in maintained shell surfaces', async () => {
  const root = await fixture({
    'setup/bootstrap.sh': 'curl -fsSL https://example.com/install.sh | sh\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('unverified remote execution')))
})

test('rejects an external download that is saved but never verified', async () => {
  const root = await fixture({
    'setup/install.sh': 'curl -fsSL https://example.com/tool -o tool\nchmod +x tool\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('unverified remote download')))
})

test('rejects variable-indirected curl commands', async () => {
  const root = await fixture({
    'setup/install.sh': 'source_url=https://example.com/install.sh\ncurl -fsSL "$source_url" | sh\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('dynamic curl/wget source')))
})

test('rejects curl command substitution assignments', async () => {
  const root = await fixture({
    'setup/install.sh': 'payload=$(curl -fsSL https://example.com/install.sh)\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('unverified remote download')))
})

test('rejects eval and process-substitution remote execution wrappers', async () => {
  for (const script of [
    'eval "$(curl -fsSL https://example.com/install.sh)"\n',
    'source <(curl -fsSL https://example.com/install.sh)\n',
  ]) {
    const root = await fixture({ 'setup/install.sh': script })
    const result = await checkSupplyChainPolicy(root)
    assert.ok(result.errors.some((error) => error.includes('unreviewed remote-input callsite')))
  }
})

test('rejects Python urllib remote inputs', async () => {
  const root = await fixture({
    'scripts/install.py': 'import urllib.request\nexec(urllib.request.urlopen("https://example.com/install.py").read())\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('Python remote input')))
})

test('rejects Node fetch remote inputs', async () => {
  const root = await fixture({
    'scripts/install.mjs': 'const response = await fetch("https://example.com/tool")\nawait response.text()\n',
  })

  const result = await checkSupplyChainPolicy(root)

  assert.ok(result.errors.some((error) => error.includes('unreviewed remote-input callsite')))
})

test('allows an exact-source download verified against its declared sha256', async () => {
  const checksum = 'a'.repeat(64)
  const root = await fixture({
    'setup/install.sh': `# supply-chain-exception: verified-tool\ncurl -fsSL https://example.com/tool -o tool\nprintf '%s  %s\\n' '${checksum}' 'tool' | sha256sum -c -\nbash tool\n`,
    'supply-chain/exceptions.json': JSON.stringify({
      remoteInputs: [{
        id: 'verified-tool',
        source: 'https://example.com/tool',
        kind: 'sha256',
        sha256: checksum,
        output: 'tool',
        reason: 'Release artifact is verified before use.',
        expires: '2999-01-01',
      }],
    }),
  })

  const result = await checkSupplyChainPolicy(root, { today: '2026-08-03' })

  assert.deepEqual(result.errors, [])
})

test('checksum flow binds the downloaded file to verification and execution', async () => {
  const checksum = 'a'.repeat(64)
  const policy = {
    remoteInputs: [{
      id: 'verified-tool',
      source: 'https://example.com/tool',
      kind: 'sha256',
      sha256: checksum,
      output: 'tool',
      reason: 'Mutation fixture.',
      expires: '2999-01-01',
    }],
  }
  for (const script of [
    `# supply-chain-exception: verified-tool\ncurl -fsSL https://example.com/tool -o tool\nprintf '%s  %s\\n' '${checksum}' 'other' | sha256sum -c -\nbash tool\n`,
    `# supply-chain-exception: verified-tool\ncurl -fsSL https://example.com/tool -o tool\n# printf '%s  %s\\n' '${checksum}' 'tool' | sha256sum -c -\nbash tool\n`,
    `# supply-chain-exception: verified-tool\ncurl -fsSL https://example.com/tool -o tool\nprintf '%s  %s\\n' '${checksum}' 'tool' | sha256sum -c -\nbash other\n`,
  ]) {
    const root = await fixture({
      'setup/install.sh': script,
      'supply-chain/exceptions.json': JSON.stringify(policy),
    })
    const result = await checkSupplyChainPolicy(root, { today: '2026-08-03' })
    assert.ok(result.errors.some((error) => error.includes('canonical checksum flow')))
  }
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
