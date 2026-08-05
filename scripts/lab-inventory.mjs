#!/usr/bin/env node
/**
 * Lab inventory — machine-readable view of docs/validation-matrix.md (US-P-VALDOCS).
 *
 * Canonical source of truth: the Markdown matrix (human-edited). This module
 * parses it, enriches rows from lab frontmatter / Cleanup sections, and writes
 * infra/lab-inventory.json. CI runs `--check` to catch drift and missing rows.
 *
 * Usage:
 *   node scripts/lab-inventory.mjs              # print JSON
 *   node scripts/lab-inventory.mjs --write       # regenerate infra/lab-inventory.json
 *   node scripts/lab-inventory.mjs --check       # exit 1 if JSON drifted or a lab lacks a row
 */

import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { CONTRACTED_LABS } from './lab-contract.mjs';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const INVENTORY_PATH = 'infra/lab-inventory.json';
export const MATRIX_PATH = 'docs/validation-matrix.md';

export const AUTOMATION_TIERS = Object.freeze([
  'mock-only',
  'localstack',
  'mixed',
  'paper',
  'deferred',
]);

function stripTicks(value) {
  return value.replace(/^`+|`+$/g, '').trim();
}

export function parseMatrixRows(markdown) {
  const lines = markdown.split('\n');
  const start = lines.findIndex((line) =>
    /^\|\s*Lab\s*\|\s*Section\s*\|\s*Environment\s*\|/i.test(line),
  );
  if (start < 0) {
    throw new Error(`${MATRIX_PATH}: missing lab matrix header row`);
  }

  const rows = [];
  for (let i = start + 2; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.startsWith('|')) break;
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim());
    if (cells.length < 6) continue;
    if (/^-+$/.test(cells[0].replaceAll(' ', ''))) continue;

    const labCell = cells[0];
    const pathMatch = labCell.match(/labs\/day-[123]\/[\w.-]+\.md/);
    if (!pathMatch) continue;

    const sectionMatch = cells[1].match(/\bS\d{2}\b/);
    rows.push({
      labPath: pathMatch[0],
      section: sectionMatch?.[0] ?? cells[1],
      sectionTitle: cells[1],
      environment: cells[2],
      tools: cells[3],
      pinned: cells[4],
      validationState: stripTicks(cells[5]),
    });
  }
  return rows;
}

export function classifyAutomationTier(row) {
  if (row.validationState === 'deferred') return 'deferred';
  const env = row.environment.toLowerCase();
  if (/paper\s*✓/.test(env)) return 'paper';
  const hasMock = /mock\s*✓/.test(env) || /local\s*✓/.test(env);
  const hasLocalstack = /localstack\s*✓/.test(env);
  if (hasLocalstack && hasMock) return 'mixed';
  if (hasLocalstack) return 'localstack';
  if (hasMock) return 'mock-only';
  return 'mock-only';
}

function readEstimatedDurationMin(labMarkdown) {
  const match = labMarkdown.match(
    /\|\s*\*\*Estimated time\*\*\s*\|\s*(\d+)\s*min(?:ute)?s?/i,
  );
  return match ? Number(match[1]) : null;
}

function readCleanupCommand(labMarkdown) {
  const idx = labMarkdown.search(/^## Cleanup\b/m);
  if (idx < 0) return null;
  const rest = labMarkdown.slice(idx);
  const fence = rest.match(/```(?:bash|sh)?\n([\s\S]*?)```/);
  if (!fence) return null;
  const lines = fence[1]
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'));
  return lines[0] ?? null;
}

function dayFromPath(labPath) {
  const match = labPath.match(/labs\/day-([123])\//);
  return match ? Number(match[1]) : null;
}

function idFromPath(labPath) {
  return labPath.replace(/^labs\//, '').replace(/\.md$/, '');
}

function solutionPathFor(repoRoot, labPath) {
  const candidate = labPath.replace(/\.md$/, '.solution.md');
  return existsSync(join(repoRoot, candidate)) ? candidate : null;
}

export function findMissingMatrixLabs(inventory, contractedLabs) {
  const covered = new Set(inventory.labs.map((lab) => lab.labPath));
  return contractedLabs.filter((labPath) => !covered.has(labPath));
}

export function buildInventory({
  repoRoot = REPO_ROOT,
  contractedLabs = CONTRACTED_LABS,
} = {}) {
  const matrix = readFileSync(join(repoRoot, MATRIX_PATH), 'utf8');
  const rows = parseMatrixRows(matrix);
  const labs = rows.map((row) => {
    const labAbs = join(repoRoot, row.labPath);
    const labMarkdown = existsSync(labAbs) ? readFileSync(labAbs, 'utf8') : '';
    const automationTier = classifyAutomationTier(row);
    const day = dayFromPath(row.labPath);

    return {
      id: idFromPath(row.labPath),
      labPath: row.labPath,
      solutionPath: solutionPathFor(repoRoot, row.labPath),
      section: row.section,
      sectionTitle: row.sectionTitle,
      day,
      environment: row.environment,
      tools: row.tools,
      pinned: row.pinned,
      validationState: row.validationState,
      estimatedDurationMin: readEstimatedDurationMin(labMarkdown),
      automationTier,
      cleanupCommand: readCleanupCommand(labMarkdown),
    };
  });

  const missing = findMissingMatrixLabs({ labs }, contractedLabs);
  if (missing.length > 0) {
    throw new Error(
      `${MATRIX_PATH} missing row(s) for contracted lab(s): ${missing.join(', ')}`,
    );
  }

  return {
    schemaVersion: 1,
    sourceOfTruth: MATRIX_PATH,
    generatedBy: 'scripts/lab-inventory.mjs',
    note:
      'Markdown matrix remains the human source of truth. Regenerate JSON with ' +
      '`node scripts/lab-inventory.mjs --write` and keep CI `--check` green. ' +
      'Automation must not upgrade validationState to localstack-smoke without a recorded run.',
    labs,
  };
}

export function renderInventory(inventory) {
  return `${JSON.stringify(inventory, null, 2)}\n`;
}

export function main(argv = process.argv.slice(2)) {
  const write = argv.includes('--write');
  const check = argv.includes('--check');

  let inventory;
  try {
    inventory = buildInventory({ repoRoot: REPO_ROOT });
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
    return 1;
  }

  const rendered = renderInventory(inventory);
  const outPath = join(REPO_ROOT, INVENTORY_PATH);

  if (check) {
    if (!existsSync(outPath)) {
      console.error(`missing ${INVENTORY_PATH}; run with --write`);
      process.exitCode = 1;
      return 1;
    }
    const committed = readFileSync(outPath, 'utf8');
    if (committed !== rendered) {
      console.error(`${INVENTORY_PATH} is out of date with ${MATRIX_PATH}`);
      console.error('Regenerate: node scripts/lab-inventory.mjs --write');
      process.exitCode = 1;
      return 1;
    }
    console.log(`${INVENTORY_PATH}: OK (matches ${MATRIX_PATH})`);
    return 0;
  }

  if (write) {
    writeFileSync(outPath, rendered);
    console.log(`wrote ${INVENTORY_PATH} (${inventory.labs.length} labs)`);
    return 0;
  }

  process.stdout.write(rendered);
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
