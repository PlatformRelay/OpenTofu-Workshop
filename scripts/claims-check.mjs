#!/usr/bin/env node
// Verify every correction row in docs/claims-verification.md still points at real text.
//
// US-C-FACTS phase 1 shipped a correction list that phase 2 applied literally and
// blind. Its value was entirely in the pointers: file, line, and the exact
// quoted string. Those rot the moment anything above them shifts — and a
// stale pointer sends an editor to the wrong line with a plausible-looking
// quote, which is worse than no pointer at all.
//
// PHASE 2 FLIPPED WHAT THIS PROVES, WITHOUT CHANGING A LINE OF THIS SCRIPT.
// The checked column used to hold the PRE-correction text, so a green run meant
// "the corrections still point at real text". It now holds the APPLIED text, so
// a green run means "the corrections are still in place" — this is the
// regression guard against someone reverting or overwriting one of the 31.
// The column was renamed `Current` -> `Now reads` in the document; this script
// reads it positionally (4th cell) and so needed no change. Say that out loud
// rather than leaving a reader to infer it from a header that moved.
//
// This script re-derives the assertion FROM THE DOCUMENT rather than from a
// parallel hand-maintained list. That distinction is the whole point: an
// earlier hand-maintained version of this check reported "23 OK" while the
// document's own L5 row was wrong, because the list and the table had drifted
// apart. Parsing the table means the check cannot disagree with what ships.
//
// Contract per row:
//   | L<n> | `path` | <line-or-range> | <Now-reads cell> | <Before> | <src> |
// Every code span in the 4th cell must appear verbatim within the named
// line range, widened by WRAP_SLACK lines so a quote that wraps across two
// source lines still resolves. Multi-line edits are quoted as one span per
// source line: the search window is joined with newlines, so a single span
// straddling a line break can never match.
//
// Two failure modes this check learned the hard way, both now fatal:
//
//   * RENDER FIDELITY. To compare against source we un-escape \` and \| , but
//     a backslash inside a code span is NOT processed by the Markdown renderer
//     this repo publishes with (Python-Markdown via MkDocs). So a cell can
//     match the source perfectly and still publish "\| Decks and Day 1 \|" to
//     the reader. Un-escaping before comparing therefore HIDES a real defect.
//     Any escape inside a code span is now an error: write the cell without
//     pipes, or use ``double-backtick`` delimiters around bare backticks.
//
//   * DEGRADED GREEN. A `Now reads` cell with no code span, or a row count that
//     silently drops because a row was deleted, both used to exit 0. Both now
//     fail. A checker that cannot distinguish "verified" from "did not look"
//     is the failure this whole document exists to prevent.
//
// WHERE POINTERS (the A/B/D/I tables) ARE CHECKED TOO, AND WERE NOT.
// For a long time this script validated ONLY the 31 L-table correction rows.
// Every other table carries a `Where` column of `path:line` pointers, and those
// had no gate at all -- which is why they rotted twice with every gate green: a
// +103-line insert moved 20+ of them (US-D-DIFF-TEASER), and the Go pin bump
// left D2 pointing at `versions.env:17`, a line holding TOFU_VERSION. Both were
// caught by reading. Reading is not a gate. Two checks now cover them:
//
//   * STRUCTURAL, every pointer in every table: the file must exist and every
//     line number must be inside it. Catches a deleted file and a pointer that
//     ran off the end.
//   * SEMANTIC, the D table (toolchain pins): the pin NAME from the Claim cell
//     must appear at the line the Where cell names. This is the check that
//     catches the D2 class -- a pointer that still resolves, to the wrong line.
//     The NAME is asserted, not the value: a row may deliberately record a
//     superseded value (D2 does) while still having to point at its own pin.
//
// Three pointer spellings are resolved rather than skipped, because a checker
// that silently skips is the failure this document exists to prevent:
//   `pages/S10-.../index.md:55`  -> glob, must match exactly one directory
//   `pages/S01:319`              -> deck shorthand for that section's index.md
//   `.solution.md:250`           -> sibling of the previous pointer on the line
//   `:204-205`                   -> bare continuation of the previous pointer
//   `path.md:~676`               -> approximate, still bounds-checked
//   `path.md:402-406, 447`       -> every number in the spec is bounds-checked
//
// Usage:  node scripts/claims-check.mjs [path/to/claims-verification.md]
// Exit:   0 = every row resolved, 1 = anything else
//
// Expected output when healthy:
//   claims-check: 31 correction row(s) - 31 resolved, 0 failed, 0 skipped
// If the row count changes because you added or removed a correction, update
// EXPECTED_ROWS below in the same commit. That deliberate friction is the
// point: a row must not be able to vanish quietly.

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DOC = process.argv[2]
  ? resolve(process.cwd(), process.argv[2])
  : join(REPO_ROOT, 'docs', 'claims-verification.md');

// A quote may wrap onto the following source line; allow a small window either
// side rather than demanding an exact hit. Kept tight so a stale pointer still
// fails instead of finding its text 40 lines away.
const WRAP_SLACK = 2;

// A row must not be able to disappear without someone noticing. Bump this in
// the same commit that adds or removes a correction row.
const EXPECTED_ROWS = 31;

/** Code spans exactly as authored, before any un-escaping. */
function rawCodeSpans(cell) {
  const spans = [];
  const remainder = cell.replace(/``.+?``/g, (m) => {
    spans.push(m.slice(2, -2));
    return ' ';
  });
  remainder.replace(/`([^`]+?)`/g, (_m, inner) => {
    spans.push(inner);
    return '';
  });
  return spans.map((x) => x.trim()).filter(Boolean);
}

/**
 * Find backslash escapes that sit INSIDE a code span.
 *
 * Testing the parsed span *content* is not enough, and that gap shipped a real
 * defect: in `` `a (\`b\`).` `` the span content ends at the backslash, so the
 * escaped backtick never appears *within* any single span and a content-based
 * test reports clean. Scan the raw line instead and ask whether the backslash's
 * column falls inside a code-span region.
 *
 * Only `\` and `\|` are flagged. `\.` and friends are left alone: a regex
 * quoted in prose is meant to show its backslash.
 */
function escapesInsideCodeSpans(line) {
  // Map code-span regions by backtick runs, the way CommonMark pairs them.
  const regions = [];
  const runs = [...line.matchAll(/`+/g)].map((m) => ({ i: m.index, len: m[0].length }));
  const used = new Set();
  for (let a = 0; a < runs.length; a++) {
    if (used.has(a)) continue;
    for (let b = a + 1; b < runs.length; b++) {
      if (used.has(b) || runs[b].len !== runs[a].len) continue;
      regions.push([runs[a].i + runs[a].len, runs[b].i]);
      used.add(a);
      used.add(b);
      break;
    }
  }
  const hits = [];
  for (let i = 0; i < line.length - 1; i++) {
    if (line[i] !== '\\') continue;
    if (line[i + 1] !== '`' && line[i + 1] !== '|') continue;
    if (regions.some(([lo, hi]) => i >= lo && i < hi)) {
      hits.push({ col: i + 1, context: line.slice(Math.max(0, i - 30), i + 20) });
    }
  }
  return hits;
}

/** Pull code spans out of a markdown table cell, longest delimiter first. */
function codeSpans(cell) {
  const spans = [];
  // ``double`` first - they legitimately contain single backticks.
  const remainder = cell.replace(/``.+?``/g, (m) => {
    spans.push(m.slice(2, -2));
    return ' ';
  });
  // then `single`
  remainder.replace(/`([^`]+?)`/g, (_m, inner) => {
    spans.push(inner);
    return '';
  });
  return spans
    // Inside a table cell, backticks and pipes are escaped for the table
    // parser (\` and \|); the source text they quote has them bare. Undo the
    // table-escaping before comparing, or every quote containing a pipe fails.
    .map((s) => s.replace(/\\`/g, '`').replace(/\\\|/g, '|').trim())
    .filter(Boolean);
}

/** "204-205" -> [204,205];  "65" -> [65,65] */
function parseLines(spec) {
  const m = spec.trim().match(/^(\d+)\s*(?:[-–]\s*(\d+))?$/);
  if (!m) return null;
  return [Number(m[1]), Number(m[2] ?? m[1])];
}

const doc = readFileSync(DOC, 'utf8').split('\n');
const rows = [];
const unparsed = [];
for (const line of doc) {
  // Anything that *declares* itself a correction row must parse. Counting
  // declarations separately from successful parses closes a silent-skip hole:
  // a File cell written with ``double backticks`` used to slip past the row
  // regex entirely, so the row never got checked and the run still exited 0.
  if (!/^\|\s*L\d+\s*\|/.test(line)) continue;
  const m = line.match(/^\|\s*(L\d+)\s*\|\s*(?:``\s*(.+?)\s*``|`([^`]+)`)\s*\|\s*([^|]+?)\s*\|(.*)$/);
  if (!m) {
    unparsed.push(line.slice(0, 90));
    continue;
  }
  const [, id, pathDouble, pathSingle, lineSpec, rest] = m;
  const cells = rest.split(/\s\|\s/);
  rows.push({ id, path: pathDouble ?? pathSingle, lineSpec, current: cells[0] ?? '' });
}

if (rows.length === 0) {
  console.error(`claims-check: no correction rows found in ${DOC}`);
  process.exit(1);
}

let ok = 0;
let failed = 0;
let skipped = 0;
const problems = [];

for (const row of rows) {
  const abs = join(REPO_ROOT, row.path);
  if (!existsSync(abs)) {
    failed++;
    problems.push(`${row.id}: file does not exist - ${row.path}`);
    continue;
  }
  const range = parseLines(row.lineSpec);
  if (!range) {
    failed++;
    problems.push(`${row.id}: unparseable line spec ${JSON.stringify(row.lineSpec)}`);
    continue;
  }
  const rawSpans = rawCodeSpans(row.current);
  const unrenderable = rawSpans.filter((s) => /\\[`|]/.test(s));
  if (unrenderable.length) {
    failed++;
    for (const s of unrenderable) {
      problems.push(
        `${row.id}: WOULD NOT RENDER - code span contains a backslash escape, ` +
        `which Python-Markdown emits literally` +
        `\n      cell: ${JSON.stringify(s)}` +
        `\n      fix: drop the pipe from the quote, or use \`\`double backticks\`\` ` +
        `around bare backticks`
      );
    }
    continue;
  }
  const spans = codeSpans(row.current);
  if (spans.length === 0) {
    failed++;
    problems.push(
      `${row.id}: NO CODE SPAN in the "Now reads" cell - nothing to verify. ` +
      `Quote the source text so this row is checkable.`
    );
    continue;
  }
  const src = readFileSync(abs, 'utf8').split('\n');
  const lo = Math.max(1, range[0] - WRAP_SLACK);
  const hi = Math.min(src.length, range[1] + WRAP_SLACK);
  const window = src.slice(lo - 1, hi).join('\n');

  const missing = spans.filter((s) => !window.includes(s));
  if (missing.length) {
    failed++;
    for (const s of missing) {
      problems.push(
        `${row.id}: NOT FOUND in ${row.path}:${row.lineSpec} (searched ${lo}-${hi})` +
        `\n      wanted: ${JSON.stringify(s)}`
      );
    }
  } else {
    ok++;
  }
}

// --- Where pointers (A/B/D/I tables) -------------------------------------
// See the header note: these carried no gate at all, and rotted twice for it.

/**
 * Anything shaped like `something:12` or `something:12-14, 20` in a code span.
 *
 * DELIBERATELY LOOSE. An earlier version whitelisted file extensions, which
 * silently skipped every pointer spelled another way — five live ones in this
 * very document (`pages/S10:65`, `pages/S11:231,239`, `pages/S14:221`,
 * `pages/S11:131`, `pages/S01:319`). A pointer that is not matched is not
 * checked and not reported, which is the degraded-green this file exists to
 * prevent. Match everything that looks like a pointer, then REPORT anything
 * that cannot be resolved instead of dropping it.
 *
 * Timestamps do not match: the spec must run to the closing backtick, so
 * `2025-07-15T14:33:31Z` fails (`:31Z` is left over) and never reaches
 * resolution.
 */
const POINTER =
  /`([^`\s]*):~?(\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*~?\d+(?:\s*[-–]\s*\d+)?)*)`/g;

/**
 * Blank out ``double-backtick`` spans, which quote literal document text rather
 * than pointers. Without this the LocalStack port in ``OpenTofu >=1.9; `:4566` ``
 * reads as a bare continuation and resolves against whatever pointer preceded it
 * on the line -- on doc line 656 that is `infra/lab-inventory.json`, so the gate
 * would report a confident, entirely fictional past-EOF failure.
 * Replaced with spaces so nothing else on the line shifts.
 */
function maskDoubleSpans(line) {
  return line.replace(/``[\s\S]*?``/g, (m) => ' '.repeat(m.length));
}

/** Does this look like a path at all, as opposed to a version or a time? */
function looksLikePath(p) {
  if (p.includes('://')) return false;
  return p.includes('/') || /\.[A-Za-z0-9]+$/.test(p);
}

/** Lines in a file, not counting the empty string after a trailing newline. */
function lineCountOf(text) {
  const parts = text.split('\n');
  if (parts.length && parts[parts.length - 1] === '') parts.pop();
  return parts.length;
}

/** Expand a `dir/PREFIX...` segment to the one directory it can mean. */
function globOneDir(prefix, stem) {
  const dir = join(REPO_ROOT, prefix);
  if (!existsSync(dir)) return { error: `directory does not exist: ${prefix}` };
  const hits = readdirSync(dir).filter((d) => d.startsWith(stem));
  if (hits.length === 0) return { error: `no directory matches ${prefix}${stem}*` };
  if (hits.length > 1) {
    return { error: `ambiguous - ${prefix}${stem}* matches ${hits.length}: ${hits.join(', ')}` };
  }
  return { dir: hits[0] };
}

/**
 * Resolve the three spellings this document uses, plus the deck shorthand.
 * `lastFull` is the previous resolved pointer on the same line, which is what
 * a bare `.solution.md:250` is relative to.
 */
function resolvePointer(raw, lastFull) {
  // `:204-205` — a bare continuation, same idiom as `.solution.md:250`: more
  // lines in the file the previous pointer on this line already named.
  if (raw === '') {
    // With no preceding pointer on the line it is a reference to THIS document
    // -- the inventory rows use it that way ("once in the sweep-technique
    // paragraph (`:430`)"). Resolved against the doc so it is bounds-checked
    // like any other, rather than reported as unanchorable.
    if (!lastFull) return { path: DOC_REL };
    return { path: lastFull };
  }
  // `.solution.md:250` — the sibling of the pointer before it on the line.
  if (raw.startsWith('.solution.md')) {
    if (!lastFull) return { error: '`.solution.md` shorthand with no preceding pointer on the line' };
    return { path: `${lastFull.replace(/\.md$/, '')}.solution.md` };
  }
  // `pages/S10-.../index.md` — an elided directory name.
  const ell = raw.match(/^(.*?)([^/]*)\.\.\.\/(.*)$/);
  if (ell) {
    const [, prefix, stem, tail] = ell;
    const g = globOneDir(prefix, stem);
    if (g.error) return { error: g.error };
    return { path: `${prefix}${g.dir}/${tail}` };
  }
  // `pages/S01:319` — deck shorthand for that section's index.md.
  const deck = raw.match(/^pages\/(S\d+)$/);
  if (deck) {
    const g = globOneDir('pages/', deck[1]);
    if (g.error) return { error: g.error };
    return { path: `pages/${g.dir}/index.md` };
  }
  if (!looksLikePath(raw)) return { skip: true };
  return { path: raw };
}

// The document's own path, for bare `:line` self-references. When a copy is
// passed on argv (the mutation probes do this) it may sit outside the repo, so
// fall back to the canonical location rather than resolving to nothing.
const DOC_REL = DOC.startsWith(REPO_ROOT + '/')
  ? DOC.slice(REPO_ROOT.length + 1)
  : 'docs/claims-verification.md';

let pointersChecked = 0;
const pointerProblems = [];

doc.forEach((rawLine, idx) => {
  if (!/^\|/.test(rawLine)) return;
  const line = maskDoubleSpans(rawLine);
  let lastFull = null;
  for (const m of line.matchAll(POINTER)) {
    const [, raw, spec] = m;
    const r = resolvePointer(raw, lastFull);
    if (r.skip) continue;
    if (r.error) {
      pointerProblems.push(`doc:${idx + 1}: ${raw} - ${r.error}`);
      continue;
    }
    // A continuation does not become the new anchor; `.solution.md` does not
    // either, or a second continuation would chain off the sibling.
    if (raw !== '' && !raw.startsWith('.solution.md')) lastFull = r.path;

    const abs = join(REPO_ROOT, r.path);
    if (!existsSync(abs)) {
      pointerProblems.push(`doc:${idx + 1}: ${raw} -> ${r.path} does not exist`);
      continue;
    }
    const count = lineCountOf(readFileSync(abs, 'utf8'));
    for (const part of spec.split(',')) {
      for (const nRaw of part.trim().split(/[-–]/)) {
        const n = Number(nRaw.trim());
        if (!Number.isFinite(n) || n < 1) {
          pointerProblems.push(`doc:${idx + 1}: ${r.path}:${nRaw.trim()} is not a valid line number`);
        } else if (n > count) {
          pointerProblems.push(
            `doc:${idx + 1}: ${r.path}:${n} is past EOF (file has ${count} lines)`
          );
        }
      }
    }
    pointersChecked++;
  }
});

// EXACT, not a floor. A floor was tried and was worthless: set at 130 against a
// live 138 it still greened after DELETING THE WHOLE OF TABLE I, because seven
// of the twelve sections hold eight pointers or fewer — less than the floor's
// own slack. An exact count carries the same deliberate friction as
// EXPECTED_ROWS: if you add or remove evidence, update this in the same commit.
const EXPECTED_POINTERS = 157;
if (pointersChecked !== EXPECTED_POINTERS) {
  pointerProblems.push(
    `${pointersChecked} Where pointer(s) checked, expected exactly ${EXPECTED_POINTERS} - ` +
    `evidence was added or removed. If deliberate, update EXPECTED_POINTERS in this script.`
  );
}

// D table: the pin NAME must live at the line the Where column names.
//
// Every `| D<n> |` row is counted, and the pin check keys off a CODE SPAN in
// the Claim cell rather than the shape of the whole cell. Matching the cell
// shape let a row disarm itself silently: wrapping the claim in bold — a style
// D5 already uses — stopped the row matching, so the historical D2 rot passed
// with exit 0 while the summary still said the pin rows had been checked.
// Two counts are asserted so neither a vanishing row nor a skipped one is quiet.
const EXPECTED_D_ROWS = 5;
const EXPECTED_PIN_ROWS = 4;
let dRows = 0;
let pinRows = 0;
for (const rawLine of doc) {
  const line = maskDoubleSpans(rawLine);
  const m = line.match(/^\|\s*(D\d+)\s*\|([^|]*)\|([^|]*)\|/);
  if (!m) continue;
  const [, id, claimCell, whereCell] = m;
  dRows++;
  const pin = codeSpans(claimCell)
    .map((s) => s.match(/^([A-Z][A-Z0-9_]*)=/))
    .find(Boolean);
  if (!pin) continue; // e.g. D5, whose claim is prose, not a NAME=value pin
  pinRows++;
  const name = pin[1];
  const first = [...whereCell.matchAll(POINTER)][0];
  if (!first) {
    pointerProblems.push(`${id}: no \`path:line\` pointer in the Where cell`);
    continue;
  }
  const r = resolvePointer(first[1], null);
  if (r.error || r.skip) {
    pointerProblems.push(`${id}: ${first[1]} - ${r.error ?? 'not resolvable as a path'}`);
    continue;
  }
  const abs = join(REPO_ROOT, r.path);
  if (!existsSync(abs)) {
    pointerProblems.push(`${id}: ${r.path} does not exist`);
    continue;
  }
  const src = readFileSync(abs, 'utf8').split('\n');
  const ln = Number(first[2].split(/[-–,]/)[0].trim());
  if (ln > lineCountOf(readFileSync(abs, 'utf8'))) {
    pointerProblems.push(`${id}: ${r.path}:${ln} is past EOF - cannot anchor ${name}`);
    continue;
  }
  // EXACT line, no slack. The claim is that the pin lives at the line named;
  // a +/-2 window accepted D2 pointing at line 29, inside the LocalStack block.
  if (!(src[ln - 1] ?? '').includes(name)) {
    pointerProblems.push(
      `${id}: ${r.path}:${ln} does not mention ${name}` +
      `\n      line ${ln} reads: ${JSON.stringify((src[ln - 1] ?? '').slice(0, 70))}` +
      `\n      the pointer resolves but names the wrong line - re-derive it by grepping`
    );
  }
}
if (dRows !== EXPECTED_D_ROWS) {
  pointerProblems.push(
    `${dRows} D<n> row(s) found, expected ${EXPECTED_D_ROWS} - a pin row was added or removed`
  );
}
if (pinRows !== EXPECTED_PIN_ROWS) {
  pointerProblems.push(
    `${pinRows} of ${dRows} D<n> row(s) carried a NAME=value pin, expected ${EXPECTED_PIN_ROWS} - ` +
    `a pin row stopped being recognised (bolding the claim does this) and was checked by nothing`
  );
}

failed += pointerProblems.length;
for (const pp of pointerProblems) problems.push(pp);


// RENDER FIDELITY, whole-file. This guard has now been rescoped twice, and each
// time the defect moved to wherever the guard was not looking:
//
//   v1  checked the checked column only  -> escapes appeared in its neighbour
//   v2  checked table rows only          -> an escape appeared in PROSE, in the
//                                           very commit that rescoped it
//
// The lesson is the scoping, not the typo: a guard aimed at where the bug was
// last seen is not a guard. It now reads every line of the file. Fenced blocks
// are included deliberately -- a broken escape is just as unreadable there.
let renderBad = 0;
let inFence = false;
doc.forEach((line, idx) => {
  if (/^\s*(```|~~~)/.test(line)) {
    inFence = !inFence;
    return;
  }
  if (inFence) return;
  for (const hit of escapesInsideCodeSpans(line)) {
    renderBad++;
    problems.push(
      `${DOC.split('/').pop()}:${idx + 1}:${hit.col}: WOULD NOT RENDER - backslash ` +
      `escape inside a code span; Python-Markdown emits it literally and ends the ` +
      `span early` +
      `\n      context: ${JSON.stringify(hit.context)}` +
      `\n      fix: drop the pipe from the quote, or wrap bare backticks in ` +
      `\`\`double backticks\`\``
    );
  }
});
failed += renderBad;

if (unparsed.length) {
  failed += unparsed.length;
  for (const u of unparsed) {
    problems.push(
      `UNPARSED correction row - it declares an L-id but does not match the row ` +
      `grammar, so it was never checked:\n      ${u}`
    );
  }
}

if (rows.length !== EXPECTED_ROWS) {
  failed++;
  problems.push(
    `row count is ${rows.length}, expected ${EXPECTED_ROWS} - a correction row was ` +
    `added or removed. If deliberate, update EXPECTED_ROWS in this script.`
  );
}

for (const p of problems) console.log(`  ${p}`);
console.log(
  `claims-check: ${rows.length} correction row(s) - ${ok} resolved, ${failed} failed, ${skipped} skipped; ` +
  `${pointersChecked} Where pointer(s), ${dRows} D row(s), ${pinRows} pin row(s) checked`
);
process.exit(failed ? 1 : 0);
