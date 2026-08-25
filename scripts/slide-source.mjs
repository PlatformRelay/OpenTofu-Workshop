/**
 * Static reader for Slidev slide sources under `pages/**\/index.md`.
 *
 * Why hand-rolled: `@slidev/parser` is only a transitive dependency here, and
 * pnpm does not hoist it, so `import('@slidev/parser')` is not resolvable from
 * `scripts/`. `splitSlides()` below is a deliberate port of that package's
 * `parseSync()` slide-boundary loop (`@slidev/parser/dist/core.mjs`, v52.19.0):
 * a `---` line only separates slides when it is not inside a fenced code block
 * and not inside an HTML comment, and it opens a frontmatter block when the
 * next line is non-empty.
 *
 * The port covers boundary detection and frontmatter extraction only. It does
 * NOT reimplement Slidev's `src:` imports, `matter` engines other than YAML, or
 * any rendering.
 */
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { parse as parseYaml } from 'yaml'

const RE_CRLF = /\r\n|\r|\n/
const RE_LEADING_BACKTICKS = /^\s*`+/

/** Recursively collect every `index.md` under `dir`. */
export function collectPageIndexes(dir, acc = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const abs = join(dir, entry.name)
    if (entry.isDirectory()) collectPageIndexes(abs, acc)
    else if (entry.isFile() && entry.name === 'index.md') acc.push(abs)
  }
  return acc.sort()
}

/** Track whether `line` leaves us inside an HTML comment. Port of Slidev's helper. */
function advanceHtmlCommentState(line, inHtmlComment) {
  let cursor = 0
  while (cursor < line.length) {
    if (inHtmlComment) {
      const end = line.indexOf('-->', cursor)
      if (end < 0) return true
      inHtmlComment = false
      cursor = end + 3
    } else {
      const start = line.indexOf('<!--', cursor)
      if (start < 0) return false
      const end = line.indexOf('-->', start + 4)
      if (end < 0) return true
      cursor = end + 3
    }
  }
  return inHtmlComment
}

/**
 * Split a Slidev markdown source into slides.
 *
 * Returns `{ index, startLine, frontmatter, frontmatterRaw, body, bodyStartLine }`
 * per slide, where `startLine` / `bodyStartLine` are 1-based for error messages
 * and `frontmatter` is the parsed YAML object (`{}` when the slide has none).
 */
export function splitSlides(markdown) {
  const lines = markdown.split(RE_CRLF)
  const slides = []
  let start = 0
  let contentStart = 0
  let inHtmlComment = false

  const slice = (end) => {
    if (start === end) return
    const chunk = lines.slice(start, end)
    const fmLines = contentStart > start ? lines.slice(start + 1, contentStart - 1) : null
    const frontmatterRaw = fmLines ? fmLines.join('\n') : null
    let frontmatter = {}
    if (frontmatterRaw !== null && frontmatterRaw.trim()) {
      // Let a YAML syntax error surface: a slide whose frontmatter does not
      // parse is exactly the case where a silent `{}` would hide a defect.
      frontmatter = parseYaml(frontmatterRaw) ?? {}
    }
    slides.push({
      index: slides.length,
      startLine: start + 1,
      raw: chunk.join('\n'),
      frontmatter,
      frontmatterRaw,
      body: lines.slice(contentStart, end).join('\n'),
      bodyStartLine: contentStart + 1,
    })
    start = end + 1
    contentStart = end + 1
  }

  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i]
    const line = rawLine.trimEnd()
    if (inHtmlComment) {
      inHtmlComment = advanceHtmlCommentState(rawLine, true)
      continue
    }
    if (line.startsWith('---')) {
      slice(i)
      const next = lines[i + 1]
      if (line[3] !== '-' && next?.trim()) {
        start = i
        for (i += 1; i < lines.length; i++) if (lines[i].trimEnd() === '---') break
        contentStart = i + 1
      }
    } else if (line.trimStart().startsWith('```')) {
      const codeBlockLevel = line.match(RE_LEADING_BACKTICKS)[0]
      let j = i + 1
      for (; j < lines.length; j++) if (lines[j].startsWith(codeBlockLevel)) break
      if (j !== lines.length) i = j
    } else {
      inHtmlComment = advanceHtmlCommentState(rawLine, false)
    }
  }
  if (start <= lines.length - 1) slice(lines.length)
  return slides
}

/** Read and split every page section deck under `<root>/pages`. */
export function readPageSlides(root) {
  return collectPageIndexes(join(root, 'pages')).map((abs) => ({
    abs,
    slides: splitSlides(readFileSync(abs, 'utf8')),
  }))
}

/** Strip every HTML comment. Comment bodies are not rendered as elements. */
export function stripHtmlComments(body) {
  return body.replace(/<!--[\s\S]*?-->/g, '')
}
