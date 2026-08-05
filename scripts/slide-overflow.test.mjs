import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, it } from 'node:test'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const MAX_CODE_LINE = 64

function collectPageIndexes(dir, acc = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const abs = join(dir, entry.name)
    if (entry.isDirectory()) collectPageIndexes(abs, acc)
    else if (entry.isFile() && entry.name === 'index.md') acc.push(abs)
  }
  return acc
}

/** Return long lines in code-annotated slide fences (relative path, 1-based line). */
function codeAnnotatedOverflows(src, relPath) {
  const hits = []
  for (const slide of src.split(/\n---\n/)) {
    if (!/^layout:\s*code-annotated/m.test(slide)) continue
    for (const m of slide.matchAll(/```[\w-]*[^\n]*\n([\s\S]*?)```/g)) {
      for (const [i, line] of m[1].split('\n').entries()) {
        if (line.length > MAX_CODE_LINE) {
          hits.push({ relPath, lineNo: i + 1, line })
        }
      }
    }
  }
  return hits
}

describe('code-annotated slides stay within export-safe column width', () => {
  it('no page index.md has ultra-wide fenced code on code-annotated slides', () => {
    const pagesDir = join(root, 'pages')
    const files = collectPageIndexes(pagesDir)
    assert.ok(files.length > 0, 'expected pages/**/index.md files')
    const violations = []
    for (const abs of files) {
      const relPath = relative(root, abs)
      violations.push(...codeAnnotatedOverflows(readFileSync(abs, 'utf8'), relPath))
    }
    assert.deepEqual(
      violations,
      [],
      violations.length
        ? `lines longer than ${MAX_CODE_LINE}:\n${violations.map((v) => `${v.relPath} (fence line ${v.lineNo}): ${v.line}`).join('\n')}`
        : undefined,
    )
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
