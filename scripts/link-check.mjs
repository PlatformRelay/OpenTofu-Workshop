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
// EXCEPTION (US-O-LINKS404): links to our OWN published site (mkdocs.yml
// site_url) and GitHub-absolute links into our OWN repo (repo_url /blob|/tree)
// are fully checkable offline against this tree, so they DO gate: a self link
// must land on a page/file that exists (and its anchor on a real heading).
// Relative links from published docs that escape docs_dir also gate — they
// resolve on GitHub but 404 on the rendered site.
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
    // Never descend into dot-directories: untracked labs/**/.terraform provider
    // caches ship vendored markdown whose links resolve nowhere (RELSE-2 —
    // hundreds of phantom errors on a lived-in checkout), and no checked doc
    // legitimately lives under a hidden directory.
    if (entry.isDirectory() && entry.name.startsWith('.')) continue;
    const rel = join(dir, entry.name);
    if (entry.isDirectory()) collectMarkdown(rel, acc, repoRoot);
    else if (entry.isFile() && entry.name.endsWith('.md')) acc.push(rel);
  }
  return acc;
}

// --- Published-site model (US-O-LINKS404) -------------------------------------
// Minimal mkdocs.yml reader — site_url, repo_url, docs_dir, exclude_docs.
// Deliberately not a YAML parser: these are all flat scalar keys plus one
// block-scalar list, and zero runtime dependencies is a design constraint.
export function loadSiteConfig(repoRoot = REPO_ROOT) {
  const path = resolve(repoRoot, 'mkdocs.yml');
  if (!existsSync(path)) return null;
  const yml = readFileSync(path, 'utf8');
  const scalar = (key) => (yml.match(new RegExp(`^${key}:\\s*(\\S+)`, 'm')) || [])[1];
  const siteUrl = scalar('site_url');
  const repoUrl = scalar('repo_url');
  const docsDir = scalar('docs_dir') || 'docs';
  const excludeDocs = [];
  const block = yml.match(/^exclude_docs:\s*\|\n((?:[ \t]+\S.*\n?)*)/m);
  if (block) {
    for (const line of block[1].split('\n')) {
      const pattern = line.trim();
      if (pattern) excludeDocs.push(pattern);
    }
  }
  if (!siteUrl && !repoUrl) return null;
  return {
    siteUrl: siteUrl ? `${siteUrl.replace(/\/+$/, '')}/` : null,
    repoUrl: repoUrl ? repoUrl.replace(/\/+$/, '') : null,
    docsDir,
    excludeDocs,
    // Site paths that are NOT mkdocs pages: the Slidev decks are built into
    // site/deck/* by scripts/pages-build.sh, so /deck/ self links cannot be
    // resolved against docs_dir and stay informational.
    passthrough: ['deck/'],
  };
}

/** gitignore-style match for mkdocs exclude_docs (prefix/** or exact file). */
function isExcludedDoc(relToDocsDir, excludeDocs) {
  return excludeDocs.some((pattern) =>
    pattern.endsWith('/**')
      ? relToDocsDir.startsWith(pattern.slice(0, -2))
      : relToDocsDir === pattern
  );
}

export function discoverDocs({ repoRoot = REPO_ROOT } = {}) {
  const docs = ['README.md'];
  // US-O-ROADMAP: the public roadmap is a root doc too — its links must
  // resolve just like the README's. Guarded so fixture repos without one pass.
  if (existsSync(resolve(repoRoot, 'ROADMAP.md'))) docs.push('ROADMAP.md');
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

export function checkLinks({
  repoRoot = REPO_ROOT,
  docs = discoverDocs({ repoRoot }),
  site = loadSiteConfig(repoRoot),
} = {}) {
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

    // Is THIS doc a published mkdocs page? (Excluded docs — e.g. the ADR tree —
    // are tracked references viewed on GitHub, so escaping docs_dir is fine
    // there and only plain file existence is enforced.)
    const docsDirPrefix = site ? `${site.docsDir}/` : null;
    const publishedPage =
      site &&
      doc.startsWith(docsDirPrefix) &&
      !isExcludedDoc(doc.slice(docsDirPrefix.length), site.excludeDocs);

    // Resolve one of OUR site's page URLs ("facilitator-runbook/#day-1-fit-plan")
    // against docs_dir. Returns true when the link was handled as a self link.
    function checkSiteSelfLink(target, line) {
      if (!site?.siteUrl || !target.startsWith(site.siteUrl)) return false;
      const [rawPath, anchor] = target.slice(site.siteUrl.length).split('#');
      const sitePath = decodeURIComponent(rawPath);
      if (site.passthrough.some((prefix) => sitePath === prefix.replace(/\/$/, '') || sitePath.startsWith(prefix))) {
        info.push(`${doc}:${line}: site (unresolvable build artifact) ${target}`);
        return true;
      }
      const clean = sitePath.replace(/\/+$/, '');
      const candidates =
        clean === ''
          ? ['index.md']
          : /\.[a-z0-9]+$/i.test(clean) && !clean.endsWith('.md')
            ? [clean]
            : [`${clean}.md`, `${clean}/index.md`];
      const found = candidates.find((rel) =>
        existsSync(resolve(repoRoot, site.docsDir, rel))
      );
      if (!found) {
        errors.push(
          `${doc}:${line}: site link ${target} resolves to no published page ` +
            `(no ${site.docsDir}/${candidates.join(` or ${site.docsDir}/`)})`
        );
        return true;
      }
      if (isExcludedDoc(found, site.excludeDocs)) {
        errors.push(
          `${doc}:${line}: site link ${target} lands on ${site.docsDir}/${found}, ` +
            `which mkdocs.yml excluded from publishing`
        );
        return true;
      }
      const absFound = resolve(repoRoot, site.docsDir, found);
      if (anchor && absFound.endsWith('.md') && !slugsFor(absFound).has(anchor))
        errors.push(`${doc}:${line}: broken anchor #${anchor} in site link ${target}`);
      return true;
    }

    // Resolve a GitHub-absolute link into OUR OWN repo (blob/tree) against the
    // working tree. Issues/releases/actions/… URLs stay informational.
    function checkRepoSelfLink(target, line) {
      if (!site?.repoUrl || !target.startsWith(`${site.repoUrl}/`)) return false;
      const m = target
        .slice(site.repoUrl.length + 1)
        .match(/^(blob|tree)\/[^/#]+(?:\/([^#]*))?(?:#(.*))?$/);
      if (!m) return false;
      const relPath = decodeURIComponent(m[2] || '').replace(/\/+$/, '');
      const anchor = m[3];
      const absTarget = resolve(repoRoot, relPath);
      if (!existsSync(absTarget)) {
        errors.push(`${doc}:${line}: repo self link ${target} — ${relPath || '.'} is not in the tree`);
        return true;
      }
      if (anchor && !/^L\d+/.test(anchor) && absTarget.endsWith('.md') && !slugsFor(absTarget).has(anchor))
        errors.push(`${doc}:${line}: broken anchor #${anchor} in repo self link ${target}`);
      return true;
    }

    for (const { target, line } of extractLinks(md)) {
      if (/^(https?:|mailto:|tel:)/i.test(target)) {
        if (checkSiteSelfLink(target, line)) continue;
        if (checkRepoSelfLink(target, line)) continue;
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

      if (publishedPage) {
        // The link resolves in the repository — but does it resolve on the
        // PUBLISHED SITE? Anything pointing outside docs_dir (or into a page
        // mkdocs excludes) renders as a 404 there. Use the GitHub-absolute
        // pattern (docs/setup.md, docs/labs.md) for such targets instead.
        const absDocsDir = resolve(repoRoot, site.docsDir);
        const relToDocs = relative(absDocsDir, absTarget);
        if (relToDocs.startsWith('..')) {
          errors.push(
            `${doc}:${line}: relative link ${pathPart} escapes docs_dir — it resolves ` +
              `on GitHub but 404s on the published site; use the GitHub-absolute pattern`
          );
          continue;
        }
        if (isExcludedDoc(relToDocs, site.excludeDocs)) {
          errors.push(
            `${doc}:${line}: relative link ${pathPart} lands on ${site.docsDir}/${relToDocs}, ` +
              `which mkdocs.yml excluded from publishing (404 on the site); ` +
              `use the GitHub-absolute pattern`
          );
          continue;
        }
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
