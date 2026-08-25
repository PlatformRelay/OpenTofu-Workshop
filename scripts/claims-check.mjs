#!/usr/bin/env node
// Verify every correction row in docs/claims-verification.md still points at real text.
//
// US-C-FACTS ships a correction list that a later lane applies literally and
// blind. Its value is entirely in the pointers: file, line, and the exact
// `Current` string. Those rot the moment anything above them shifts — and a
// stale pointer sends an editor to the wrong line with a plausible-looking
// quote, which is worse than no pointer at all.
//
// This script re-derives the assertion FROM THE DOCUMENT rather than from a
// parallel hand-maintained list. That distinction is the whole point: an
// earlier hand-maintained version of this check reported "23 OK" while the
// document's own L5 row was wrong, because the list and the table had drifted
// apart. Parsing the table means the check cannot disagree with what ships.
//
// Contract per row:
//   | L<n> | `path` | <line-or-range> | <Current cell> | <Corrected> | <src> |
// Every code span in the Current cell must appear verbatim within the named
// line range, widened by WRAP_SLACK lines so a quote that wraps across two
// source lines still resolves.
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
//   * DEGRADED GREEN. A Current cell with no code span, or a row count that
//     silently drops because a row was deleted, both used to exit 0. Both now
//     fail. A checker that cannot distinguish "verified" from "did not look"
//     is the failure this whole document exists to prevent.
//
// Usage:  node scripts/claims-check.mjs [path/to/claims-verification.md]
// Exit:   0 = every row resolved, 1 = anything else
//
// Expected output when healthy:
//   claims-check: 31 correction row(s) - 31 resolved, 0 failed, 0 skipped
// If the row count changes because you added or removed a correction, update
// EXPECTED_ROWS below in the same commit. That deliberate friction is the
// point: a row must not be able to vanish quietly.

import { readFileSync, existsSync } from 'node:fs';
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
      `${row.id}: NO CODE SPAN in the Current cell - nothing to verify. ` +
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

// RENDER FIDELITY, document-wide. The first version of this guard only looked
// at each row's `Current` cell, so the defect simply relocated: escapes in
// `Corrected` cells and in the left-alone table still published literally, and
// one of them collapsed a table cell to empty, deleting real guidance from the
// page. Scope the guard to the artifact, not to one column.
let renderBad = 0;
doc.forEach((line, idx) => {
  if (!line.startsWith('|')) return;
  for (const span of rawCodeSpans(line)) {
    if (/\\[`|]/.test(span)) {
      renderBad++;
      problems.push(
        `${DOC.split('/').pop()}:${idx + 1}: WOULD NOT RENDER - code span contains a ` +
        `backslash escape, which Python-Markdown emits literally` +
        `\n      span: ${JSON.stringify(span.slice(0, 80))}` +
        `\n      fix: drop the pipe from the quote, or wrap bare backticks in ` +
        `\`\`double backticks\`\``
      );
    }
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
  `claims-check: ${rows.length} correction row(s) - ${ok} resolved, ${failed} failed, ${skipped} skipped`
);
process.exit(failed ? 1 : 0);
