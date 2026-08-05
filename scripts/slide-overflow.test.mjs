import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

/** Extract the fenced block that follows a heading substring. */
function fenceAfterHeading(src, heading, lang = 'hcl') {
  const idx = src.indexOf(heading)
  assert.ok(idx >= 0, `heading not found: ${heading}`)
  const after = src.slice(idx)
  const re = new RegExp('```' + lang + '[^\\n]*\\n([\\s\\S]*?)```')
  const m = after.match(re)
  assert.ok(m, `${lang} fence not found after: ${heading}`)
  return m[1]
}

const MAX_CODE_LINE = 64

describe('dense code-annotated slides stay within column width', () => {
  it('state encryption teaching slide has no ultra-wide hcl lines', () => {
    const src = readFileSync(join(root, 'pages/S05-state-encryption/index.md'), 'utf8')
    const block = fenceAfterHeading(src, 'The encryption block — client-side, OpenTofu-native')
    const long = block.split('\n').filter((l) => l.length > MAX_CODE_LINE)
    assert.deepEqual(long, [], `lines longer than ${MAX_CODE_LINE}:\n${long.join('\n')}`)
    assert.match(block, /encryption \{/)
  })

  it('dynamic blocks slide has no ultra-wide hcl lines', () => {
    const src = readFileSync(join(root, 'pages/S09-best-practices/index.md'), 'utf8')
    const block = fenceAfterHeading(src, 'dynamic blocks — generate repeated nested blocks')
    const long = block.split('\n').filter((l) => l.length > MAX_CODE_LINE)
    assert.deepEqual(long, [], `lines longer than ${MAX_CODE_LINE}:\n${long.join('\n')}`)
    assert.match(block, /dynamic "ingress"/)
  })
})

describe('code-annotated layout contains code column overflow', () => {
  it('sets min-width:0 and overflow on the code column', () => {
    const css = readFileSync(join(root, 'theme/layouts/code-annotated.vue'), 'utf8')
    assert.match(css, /\.kw-ca-code\s*\{[^}]*min-width:\s*0/s)
    assert.match(css, /\.kw-ca-code\s*\{[^}]*overflow:\s*auto/s)
    assert.match(css, /\.kw-ca-rail\s*\{[^}]*min-width:\s*0/s)
  })
})
