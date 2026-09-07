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
//   `.solution.md:250`           -> sibling of the previous pointer on the line
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

/** A `path:line` (or `path:1-2, 9`) code span inside a table cell. */
const POINTER =
  /`([A-Za-z0-9._\-/]+\.(?:md|env|sh|yaml|yml|tf|mjs|json|Dockerfile)):(\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)`/g;

/**
 * Expand `pages/S10-.../index.md` to the one directory it can mean.
 * Ambiguity is an error, not a skip: two matches means the pointer does not
 * identify a file, and zero means the directory is gone.
 */
function expandEllipsis(p) {
  const m = p.match(/^(.*?)([^/]*)\.\.\.\/(.*)$/);
  if (!m) return { path: p };
  const [, prefix, stem, tail] = m;
  const dir = join(REPO_ROOT, prefix);
  if (!existsSync(dir)) return { error: `directory does not exist: ${prefix}` };
  const hits = readdirSync(dir).filter((d) => d.startsWith(stem));
  if (hits.length === 0) return { error: `no directory matches ${prefix}${stem}*` };
  if (hits.length > 1) {
    return { error: `ambiguous - ${prefix}${stem}* matches ${hits.length}: ${hits.join(', ')}` };
  }
  return { path: `${prefix}${hits[0]}/${tail}` };
}

/** Every line number a spec names, ranges expanded to their endpoints. */
function specNumbers(spec) {
  const out = [];
  for (const part of spec.split(',')) {
    for (const n of part.trim().split(/[-–]/)) {
      const v = Number(n.trim());
      if (Number.isFinite(v)) out.push(v);
    }
  }
  return out;
}

let pointersChecked = 0;
const pointerProblems = [];

doc.forEach((line, idx) => {
  if (!/^\|/.test(line)) return;
  let lastFull = null;
  for (const m of line.matchAll(POINTER)) {
    const [, rawPath, spec] = m;
    let path = rawPath;

    // `.solution.md:250` is shorthand for the sibling of the pointer before it.
    if (path.startsWith('.solution.md')) {
      if (!lastFull) {
        pointerProblems.push(
          `doc:${idx + 1}: \`.solution.md\` shorthand with no preceding pointer on the line`
        );
        continue;
      }
      path = `${lastFull.replace(/\.md$/, '')}.solution.md`;
    } else {
      const expanded = expandEllipsis(path);
      if (expanded.error) {
        pointerProblems.push(`doc:${idx + 1}: ${rawPath} - ${expanded.error}`);
        continue;
      }
      path = expanded.path;
      lastFull = path;
    }

    const abs = join(REPO_ROOT, path);
    if (!existsSync(abs)) {
      pointerProblems.push(`doc:${idx + 1}: ${rawPath} -> ${path} does not exist`);
      continue;
    }
    const lineCount = readFileSync(abs, 'utf8').split('\n').length;
    for (const n of specNumbers(spec)) {
      if (n > lineCount) {
        pointerProblems.push(
          `doc:${idx + 1}: ${path}:${n} is past EOF (file has ${lineCount} lines)`
        );
      }
    }
    pointersChecked++;
  }
});

// A pointer set that silently empties is the degraded-green this file already
// learned about once. Assert it stayed populated.
//
// A FLOOR, not an exact count like EXPECTED_ROWS: pointers are added and removed
// whenever evidence is edited, which is often, and exact-matching them would
// turn every prose edit into a gate failure. But the floor has to be tight
// enough to catch what it exists to catch. Set at 100 it was worthless -- an
// experiment stripping the pointers from EVERY non-L table row left exactly 100
// behind, so a whole table could vanish and the floor would not move. 130
// against a live count of 138 tolerates ordinary editing and still reds if a
// table's worth of evidence disappears. Raise it when the document grows.
const EXPECTED_POINTERS_MIN = 130;
if (pointersChecked < EXPECTED_POINTERS_MIN) {
  pointerProblems.push(
    `only ${pointersChecked} Where pointer(s) checked, expected at least ` +
    `${EXPECTED_POINTERS_MIN} - the pointer scan is matching nothing, not passing`
  );
}

// D table: the pin NAME must live at the line the Where column names.
// The value is deliberately NOT asserted - D2 records a superseded value on
// purpose - but a row must still point at its own pin.
let pinRows = 0;
for (const line of doc) {
  const m = line.match(/^\|\s*(D\d+)\s*\|\s*`([A-Z][A-Z0-9_]*)=[^`]*`\s*\|\s*([^|]+?)\s*\|/);
  if (!m) continue;
  const [, id, pin, whereCell] = m;
  pinRows++;
  const first = [...whereCell.matchAll(POINTER)][0];
  if (!first) {
    pointerProblems.push(`${id}: no \`path:line\` pointer in the Where cell`);
    continue;
  }
  const expanded = expandEllipsis(first[1]);
  if (expanded.error) {
    pointerProblems.push(`${id}: ${first[1]} - ${expanded.error}`);
    continue;
  }
  const abs = join(REPO_ROOT, expanded.path);
  if (!existsSync(abs)) {
    pointerProblems.push(`${id}: ${expanded.path} does not exist`);
    continue;
  }
  const src = readFileSync(abs, 'utf8').split('\n');
  const ln = specNumbers(first[2])[0];
  // Past EOF the window would invert (lo > hi) and the message would read
  // "searched 99997-37", which is noise on top of a defect the structural pass
  // has already named precisely. Say the one true thing instead.
  if (ln > src.length) {
    pointerProblems.push(
      `${id}: ${expanded.path}:${ln} is past EOF (file has ${src.length} lines) - ` +
      `cannot anchor ${pin}`
    );
    continue;
  }
  const lo = Math.max(1, ln - WRAP_SLACK);
  const hi = Math.min(src.length, ln + WRAP_SLACK);
  if (!src.slice(lo - 1, hi).join('\n').includes(pin)) {
    pointerProblems.push(
      `${id}: ${expanded.path}:${ln} does not mention ${pin} (searched ${lo}-${hi})` +
      `\n      line ${ln} reads: ${JSON.stringify((src[ln - 1] ?? '').slice(0, 70))}` +
      `\n      the pointer resolves but names the wrong line - re-derive it by grepping`
    );
  }
}
if (pinRows === 0) {
  pointerProblems.push('no D<n> pin rows parsed - the pin anchor check verified nothing');
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
  `${pointersChecked} Where pointer(s) and ${pinRows} pin row(s) checked`
);
process.exit(failed ? 1 : 0);
