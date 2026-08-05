import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, it } from 'node:test'

import { checkLinks, discoverDocs } from './link-check.mjs'

function writeDoc(root, rel, body) {
  const abs = join(root, rel)
  mkdirSync(join(abs, '..'), { recursive: true })
  writeFileSync(abs, body)
  return rel
}

function fixtureRepo(docBody) {
  const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
  writeDoc(root, 'README.md', '# Root\n')
  const doc = writeDoc(root, 'docs/sample.md', docBody)
  return { root, doc }
}

describe('checkLinks', () => {
  it('reports missing internal target with file:line', () => {
    const { root, doc } = fixtureRepo('[broken](missing-target.md)\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /^docs\/sample\.md:1: missing internal target missing-target\.md/)
  })

  it('reports broken cross-file anchor with file:line', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
    writeDoc(root, 'README.md', '# Root\n')
    writeDoc(root, 'docs/target.md', '# Real Heading\n')
    const doc = writeDoc(root, 'docs/sample.md', '[broken](target.md#no-such-anchor)\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /^docs\/sample\.md:1: broken anchor #no-such-anchor in target\.md/)
  })

  it('reports broken same-file anchor with file:line', () => {
    const { root, doc } = fixtureRepo('# Visible\n\n[jump](#missing-anchor)\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /^docs\/sample\.md:3: broken same-file anchor #missing-anchor/)
  })

  it('reports unresolved <pages-url> placeholder with file:line', () => {
    const { root, doc } = fixtureRepo('Live deck: <pages-url>/deck/\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /^docs\/sample\.md:1: unresolved placeholder `<pages-url>`/)
  })

  it('passes when internal links and anchors resolve', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
    writeDoc(root, 'README.md', '# Root\n')
    writeDoc(root, 'docs/target.md', '# Target Section\n')
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[ok](target.md#target-section)\n\nSee <https://example.com>\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.deepEqual(errors, [])
  })
})

describe('discoverDocs', () => {
  it('collects README.md, docs/**/*.md, and labs/**/*.md', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
    writeDoc(root, 'README.md', '# Root\n')
    writeDoc(root, 'docs/alpha.md', '# Alpha\n')
    writeDoc(root, 'labs/day-1/00-setup.md', '# Lab\n')
    const docs = discoverDocs({ repoRoot: root })
    assert.deepEqual(docs, ['README.md', 'docs/alpha.md', 'labs/day-1/00-setup.md'])
  })
})
