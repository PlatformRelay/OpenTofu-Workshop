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
// source lines still resolves. Rows whose Current cell has no code span
// (prose descriptions) are reported as SKIP, not silently passed.
//
// Usage:  node scripts/claims-check.mjs [path/to/claims-verification.md]
// Exit:   0 = every row resolved, 1 = at least one row failed

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
for (const line of doc) {
  const m = line.match(/^\|\s*(L\d+)\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|(.*)$/);
  if (!m) continue;
  const [, id, path, lineSpec, rest] = m;
  const cells = rest.split(/\s\|\s/);
  rows.push({ id, path, lineSpec, current: cells[0] ?? '' });
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
  const spans = codeSpans(row.current);
  if (spans.length === 0) {
    skipped++;
    problems.push(`${row.id}: SKIP - Current cell has no code span to check`);
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

for (const p of problems) console.log(`  ${p}`);
console.log(
  `claims-check: ${rows.length} correction row(s) - ${ok} resolved, ${failed} failed, ${skipped} skipped`
);
process.exit(failed ? 1 : 0);
