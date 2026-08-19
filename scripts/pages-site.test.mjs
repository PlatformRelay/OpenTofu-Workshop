#!/usr/bin/env node
// Assert Pages workflow / build script keep Slidev under /deck/ with hash routing.
import { readFileSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

test('pages.yml builds Slidev with hash router under /deck/', () => {
  const wf = readFileSync(resolve(ROOT, '.github/workflows/pages.yml'), 'utf8')
  assert.match(wf, /pages-build\.sh/)
  assert.match(wf, /PAGES_BASE/)
  assert.match(wf, /mkdocs|MkDocs/)
})

test('pages-build.sh mirrors hash + deck layout', () => {
  const sh = readFileSync(resolve(ROOT, 'scripts/pages-build.sh'), 'utf8')
  assert.match(sh, /--router-mode hash/)
  assert.match(sh, /deck\/day-1/)
  assert.match(sh, /deck\/day-2/)
  assert.match(sh, /deck\/day-3/)
  assert.match(sh, /deck\/3day/)
  assert.match(sh, /deck\/templates/)
  assert.match(sh, /mkdocs build/)
})

test('mkdocs.yml site_url uses canonical OpenTofu-Workshop case', () => {
  const yml = readFileSync(resolve(ROOT, 'mkdocs.yml'), 'utf8')
  assert.match(yml, /site_url:\s*https:\/\/platformrelay\.github\.io\/OpenTofu-Workshop\//)
})

// US-C-ORIENT AC(1): before that story `grep -rniE 'design principle|devops'`
// over pages/S01-iac/ and `grep -rniE 'pulumi|crossplane|ansible'` over pages/
// both returned zero hits. Nothing else asserts the orientation content exists,
// so without this test a future edit could delete both new beats and leave every
// gate green. Presenter notes are stripped first: the AC requires the content on
// the slide, not only in the facilitator's notes.
test('S01 keeps its design-principles and practical-alternatives orientation', () => {
  const body = readFileSync(resolve(ROOT, 'pages/S01-iac/index.md'), 'utf8')
    .replace(/<!--[\s\S]*?-->/g, '')
  assert.match(body, /design principles?/i, 'S01 must name the design principles')
  assert.match(body, /devops/i, 'S01 must place IaC in its DevOps context')
  for (const alternative of ['pulumi', 'crossplane', 'ansible']) {
    assert.match(
      body,
      new RegExp(alternative, 'i'),
      `S01 must name ${alternative} among the practical alternatives`,
    )
  }
})

test('docs landing and run-slides exist', () => {
  assert.ok(existsSync(resolve(ROOT, 'docs/index.md')))
  assert.ok(existsSync(resolve(ROOT, 'docs/run-slides.md')))
  assert.ok(existsSync(resolve(ROOT, 'docs/downloads.md')))
})
