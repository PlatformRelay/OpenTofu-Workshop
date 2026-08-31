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

// --- US-O-LINKS404: the published-site link class -----------------------------
// The live site is MkDocs at / (docs_dir=docs) plus Slidev under /deck/.
// Three sub-classes used to sail through as "informational" or "resolves on
// disk": self links to site pages that don't exist, relative links that escape
// docs_dir (fine on GitHub, 404 on the site), and links into pages mkdocs
// excludes from publishing. Both polarities are tested for each: the planted
// defect REDS, and the fixed shape PASSES.
const MKDOCS_YML = `site_name: Fixture
site_url: https://example.github.io/Fixture-Site/
repo_url: https://github.com/Example/Fixture-Site
docs_dir: docs
exclude_docs: |
  decisions/**
  requirements-docs.txt
`

function siteFixture() {
  const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
  writeFileSync(join(root, 'mkdocs.yml'), MKDOCS_YML)
  writeDoc(root, 'README.md', '# Root\n')
  writeDoc(root, 'docs/index.md', '# Home\n')
  writeDoc(root, 'docs/target.md', '# Target Section\n')
  writeDoc(root, 'docs/decisions/0001-thing.md', '# ADR\n')
  return root
}

describe('published-site self links (US-O-LINKS404)', () => {
  it('reds on a site self link with no published page behind it', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[404](https://example.github.io/Fixture-Site/setup/localstack/)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /docs\/sample\.md:1: site link .*setup\/localstack\/ resolves to no published page/)
  })

  it('passes a site self link whose page and anchor exist', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[ok](https://example.github.io/Fixture-Site/target/#target-section)\n' +
        '[home](https://example.github.io/Fixture-Site/)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.deepEqual(errors, [])
  })

  it('reds on a site self link whose anchor is missing from the page', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[bad](https://example.github.io/Fixture-Site/target/#no-such-heading)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /broken anchor #no-such-heading/)
  })

  it('reds on a site self link into a page mkdocs excludes from publishing', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[adr](https://example.github.io/Fixture-Site/decisions/0001-thing/)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /excluded from publishing/)
  })

  it('leaves /deck/ site links informational (Slidev builds, not docs pages)', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[deck](https://example.github.io/Fixture-Site/deck/3day/)\n',
    )
    const { errors, info } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.deepEqual(errors, [])
    assert.equal(info.filter((line) => line.includes('deck/3day')).length, 1)
  })

  it('stays inert without a mkdocs.yml (fixture repos keep passing)', () => {
    const { root, doc } = fixtureRepo('[site](https://example.github.io/Fixture-Site/missing/)\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.deepEqual(errors, [])
  })
})

describe('GitHub-absolute self links (US-O-LINKS404)', () => {
  it('reds on a blob/main self link whose file is missing from the tree', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[gone](https://github.com/Example/Fixture-Site/blob/main/setup/localstack.md)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /repo self link .*setup\/localstack\.md is not in the tree/)
  })

  it('passes blob/tree self links to real files, checking md anchors', () => {
    const root = siteFixture()
    writeDoc(root, 'setup/localstack.md', '# Troubleshooting\n')
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[ok](https://github.com/Example/Fixture-Site/blob/main/setup/localstack.md#troubleshooting)\n' +
        '[dir](https://github.com/Example/Fixture-Site/tree/main/docs)\n' +
        '[line](https://github.com/Example/Fixture-Site/blob/main/README.md#L1)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.deepEqual(errors, [])
  })

  it('reds on a blob/main md self link with a broken anchor', () => {
    const root = siteFixture()
    writeDoc(root, 'setup/localstack.md', '# Troubleshooting\n')
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[bad](https://github.com/Example/Fixture-Site/blob/main/setup/localstack.md#nope)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /broken anchor #nope/)
  })

  it('leaves non-blob github links (issues, releases) informational', () => {
    const root = siteFixture()
    const doc = writeDoc(
      root,
      'docs/sample.md',
      '[issues](https://github.com/Example/Fixture-Site/issues/21)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.deepEqual(errors, [])
  })
})

describe('docs_dir escapes (US-O-LINKS404)', () => {
  it('reds on a relative link from a published doc that escapes docs_dir even when the file exists', () => {
    const root = siteFixture()
    writeDoc(root, 'CONTRIBUTING.md', '# Contributing\n')
    const doc = writeDoc(root, 'docs/sample.md', '[esc](../CONTRIBUTING.md)\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /escapes docs_dir .*404s on the published site/)
  })

  it('reds on a relative link from a published doc into an mkdocs-excluded page', () => {
    const root = siteFixture()
    const doc = writeDoc(root, 'docs/sample.md', '[adr](decisions/0001-thing.md)\n')
    const { errors } = checkLinks({ repoRoot: root, docs: [doc] })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /excluded from publishing/)
  })

  it('passes in-docs relative links, and exempts excluded docs themselves', () => {
    const root = siteFixture()
    writeDoc(root, 'CONTRIBUTING.md', '# Contributing\n')
    const inDocs = writeDoc(root, 'docs/sample.md', '[ok](target.md#target-section)\n')
    const fromAdr = writeDoc(
      root,
      'docs/decisions/0002-thing.md',
      '[up](../../CONTRIBUTING.md)\n[peer](0001-thing.md)\n',
    )
    const { errors } = checkLinks({ repoRoot: root, docs: [inDocs, fromAdr] })
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

  it('includes ROADMAP.md when it exists (US-O-ROADMAP)', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
    writeDoc(root, 'README.md', '# Root\n')
    writeDoc(root, 'ROADMAP.md', '# Roadmap\n')
    const docs = discoverDocs({ repoRoot: root })
    assert.deepEqual(docs, ['README.md', 'ROADMAP.md'])
  })

  it('skips dot-directories such as untracked .terraform provider caches (RELSE-2)', () => {
    // A lived-in checkout carries labs/**/.terraform provider caches full of
    // vendored READMEs with links that resolve nowhere. Discovery must never
    // descend into dot-directories, so a broken link planted there cannot red
    // the run (and the real tree stays checkable on a used machine).
    const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
    writeDoc(root, 'README.md', '# Root\n')
    writeDoc(root, 'labs/day-1/00-setup/.terraform/providers/vendor/README.md', '[gone](missing.md)\n')
    writeDoc(root, 'docs/.cache/sneaky.md', '[gone](missing.md)\n')
    const docs = discoverDocs({ repoRoot: root })
    assert.deepEqual(docs, ['README.md'])
    const { errors } = checkLinks({ repoRoot: root })
    assert.deepEqual(errors, [])
  })

  it('checkLinks reds on a broken ROADMAP.md link', () => {
    const root = mkdtempSync(join(tmpdir(), 'ot-link-check-'))
    writeDoc(root, 'README.md', '# Root\n')
    writeDoc(root, 'ROADMAP.md', '[gone](docs/missing.md)\n')
    const { errors } = checkLinks({ repoRoot: root })
    assert.equal(errors.length, 1)
    assert.match(errors[0], /^ROADMAP\.md:1: missing internal target docs\/missing\.md/)
  })
})
