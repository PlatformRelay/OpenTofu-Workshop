#!/usr/bin/env node
// Deterministic, offline link checker for workshop docs and labs.
//
// Validates across README.md, docs/**/*.md, and labs/**/*.md:
//   1. No unresolved `<pages-url>` (or similar `<…>`-style URL) placeholder remains.
//   2. Every internal (relative) link target file exists on disk.
//   3. Every in-document `#anchor` resolves to a heading in the target file,
//      using GitHub's heading-slug algorithm.
//
// External (http/https/mailto) links are reported for information only and never
// fail the check — liveness is flaky (rate limits) and must not gate CI.
//
// Zero runtime dependencies (plain Node ESM) so CI needs no install step.

import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { dirname, resolve, relative, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** Collect markdown paths under a directory (relative to repo root). */
function collectMarkdown(dir, acc, repoRoot) {
  const abs = resolve(repoRoot, dir);
  if (!existsSync(abs)) return acc;
  for (const entry of readdirSync(abs, { withFileTypes: true })) {
    const rel = join(dir, entry.name);
    if (entry.isDirectory()) collectMarkdown(rel, acc, repoRoot);
    else if (entry.isFile() && entry.name.endsWith('.md')) acc.push(rel);
  }
  return acc;
}

export function discoverDocs({ repoRoot = REPO_ROOT } = {}) {
  const docs = ['README.md'];
  for (const dir of ['docs', 'labs']) {
    collectMarkdown(dir, docs, repoRoot);
  }
  return [...new Set(docs)].sort();
}

// --- GitHub heading-slug algorithm --------------------------------------------
function slugify(heading) {
  return heading
    .trim()
    .toLowerCase()
    .replace(/[^\w\- ]/g, '')
    .replace(/ /g, '-');
}

function headingSlugs(markdown) {
  const seen = new Map();
  const slugs = new Set();
  let inFence = false;
  for (const rawLine of markdown.split('\n')) {
    if (/^\s*(```|~~~)/.test(rawLine)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    const m = rawLine.match(/^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/);
    if (!m) continue;
    let text = m[2]
      .replace(/`([^`]*)`/g, '$1')
      .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/[*_]/g, '');
    let slug = slugify(text);
    if (seen.has(slug)) {
      const n = seen.get(slug) + 1;
      seen.set(slug, n);
      slug = `${slug}-${n}`;
    } else {
      seen.set(slug, 0);
    }
    slugs.add(slug);
  }
  return slugs;
}

function extractLinks(markdown) {
  const links = [];
  const lines = markdown.split('\n');
  let inFence = false;
  const linkRe = /!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
  lines.forEach((line, i) => {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      return;
    }
    if (inFence) return;
    let m;
    while ((m = linkRe.exec(line)) !== null) {
      links.push({ target: m[1], line: i + 1 });
    }
  });
  return links;
}

function findPlaceholders(markdown) {
  const hits = [];
  const lines = markdown.split('\n');
  let inFence = false;
  const re = /<([a-z][a-z0-9-]*(?:-url|-URL|url))>/gi;
  lines.forEach((line, i) => {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      return;
    }
    if (inFence) return;
    let m;
    while ((m = re.exec(line)) !== null) {
      hits.push({ token: m[0], line: i + 1 });
    }
  });
  return hits;
}

export function checkLinks({ repoRoot = REPO_ROOT, docs = discoverDocs({ repoRoot }) } = {}) {
  const errors = [];
  const info = [];
  const slugCache = new Map();
  function slugsFor(absPath) {
    if (slugCache.has(absPath)) return slugCache.get(absPath);
    let slugs = new Set();
    if (existsSync(absPath) && statSync(absPath).isFile()) {
      slugs = headingSlugs(readFileSync(absPath, 'utf8'));
    }
    slugCache.set(absPath, slugs);
    return slugs;
  }

  for (const doc of docs) {
    const absDoc = resolve(repoRoot, doc);
    if (!existsSync(absDoc)) {
      errors.push(`${doc}: file listed for checking does not exist`);
      continue;
    }
    const md = readFileSync(absDoc, 'utf8');
    const docDir = dirname(absDoc);

    for (const { token, line } of findPlaceholders(md)) {
      errors.push(`${doc}:${line}: unresolved placeholder \`${token}\``);
    }

    for (const { target, line } of extractLinks(md)) {
      if (/^(https?:|mailto:|tel:)/i.test(target)) {
        info.push(`${doc}:${line}: external ${target}`);
        continue;
      }
      if (target.includes('<') && target.includes('>')) continue;

      const [pathPart, anchor] = target.split('#');
      if (pathPart === '') {
        if (anchor && !slugsFor(absDoc).has(anchor))
          errors.push(`${doc}:${line}: broken same-file anchor #${anchor}`);
        continue;
      }

      const absTarget = resolve(docDir, pathPart);
      if (!existsSync(absTarget)) {
        errors.push(
          `${doc}:${line}: missing internal target ${pathPart} ` +
            `(resolved ${relative(repoRoot, absTarget)})`
        );
        continue;
      }

      if (anchor && absTarget.endsWith('.md') && !slugsFor(absTarget).has(anchor))
        errors.push(`${doc}:${line}: broken anchor #${anchor} in ${pathPart}`);
    }
  }
  return { errors, info, docs };
}

function run() {
  const { errors, info, docs } = checkLinks();
  if (process.env.LINK_CHECK_VERBOSE) {
    for (const line of info) console.log(`info: ${line}`);
  }

  if (errors.length > 0) {
    console.error(`link-check: FAILED with ${errors.length} problem(s):`);
    for (const e of errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  console.log(
    `link-check: OK — ${docs.length} docs, no placeholders, ` +
      `all internal links and anchors resolve.`
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  run();
