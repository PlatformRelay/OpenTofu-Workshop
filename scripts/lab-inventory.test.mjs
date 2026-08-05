import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  AUTOMATION_TIERS,
  INVENTORY_PATH,
  MATRIX_PATH,
  buildInventory,
  classifyAutomationTier,
  findMissingMatrixLabs,
  parseMatrixRows,
  renderInventory,
} from './lab-inventory.mjs';
import { CONTRACTED_LABS } from './lab-contract.mjs';

const REPO_ROOT = resolve(fileURLToPath(new URL('.', import.meta.url)), '..');

const FIXTURE_MATRIX = `# Validation matrix (fixture)

## The matrix

| Lab | Section | Environment | Tools / deps | Pinned versions | State |
| --- | --- | --- | --- | --- | --- |
| [\`day-1/00-setup.md\`](../labs/day-1/00-setup.md) | S00 Welcome | \`localstack ✓\` · \`local ✓\` | Docker or k8s LocalStack | OpenTofu ≥1.8 | \`unrun\` |
| [\`day-1/03-core-workflow.md\`](../labs/day-1/03-core-workflow.md) | S03 Workflow | \`mock ✓ (no docker)\` | none | local + random providers | \`unit-tested\` |
| [\`day-1/11-taco-landscape.md\`](../labs/day-1/11-taco-landscape.md) | S11 TACO | \`paper ✓\` | none | n/a | \`unrun\` |
`;

function fixtureRepo() {
  const root = mkdtempSync(join(tmpdir(), 'lab-inventory-'));
  mkdirSync(join(root, 'docs'), { recursive: true });
  mkdirSync(join(root, 'labs', 'day-1'), { recursive: true });
  writeFileSync(join(root, 'docs', 'validation-matrix.md'), FIXTURE_MATRIX);
  writeFileSync(
    join(root, 'labs', 'day-1', '00-setup.md'),
    `# Lab 00

| | |
| --- | --- |
| **Estimated time** | 20 min |

## Cleanup / panic reset

\`\`\`bash
task lab:down DIR=labs/day-1/00-setup
\`\`\`
`,
  );
  writeFileSync(
    join(root, 'labs', 'day-1', '03-core-workflow.md'),
    `# Lab 03

| | |
| --- | --- |
| **Estimated time** | 20 min |

## Cleanup / panic reset

\`\`\`bash
tofu destroy -auto-approve
\`\`\`
`,
  );
  writeFileSync(
    join(root, 'labs', 'day-1', '11-taco-landscape.md'),
    `# Lab 11

| | |
| --- | --- |
| **Estimated time** | 20 min |

## Cleanup / panic reset

No tracked resources — discard your notes.
`,
  );
  return root;
}

test('parseMatrixRows reads lab paths and validation state', () => {
  const rows = parseMatrixRows(FIXTURE_MATRIX);
  assert.equal(rows.length, 3);
  assert.equal(rows[0].labPath, 'labs/day-1/00-setup.md');
  assert.equal(rows[1].section, 'S03');
  assert.equal(rows[2].validationState, 'unrun');
});

test('classifyAutomationTier covers mock, localstack, paper, and deferred', () => {
  assert.ok(AUTOMATION_TIERS.includes('mock-only'));
  assert.ok(AUTOMATION_TIERS.includes('localstack'));
  assert.equal(
    classifyAutomationTier({
      environment: 'mock ✓ (no docker)',
      validationState: 'unit-tested',
    }),
    'mock-only',
  );
  assert.equal(
    classifyAutomationTier({
      environment: 'localstack ✓ · local ✓ (no docker)',
      validationState: 'unrun',
    }),
    'mixed',
  );
  assert.equal(
    classifyAutomationTier({
      environment: 'paper ✓',
      validationState: 'unrun',
    }),
    'paper',
  );
  assert.equal(
    classifyAutomationTier({
      environment: 'mock ✓',
      validationState: 'deferred',
    }),
    'deferred',
  );
});

test('findMissingMatrixLabs fails when a contracted lab has no matrix row', () => {
  const rows = parseMatrixRows(FIXTURE_MATRIX);
  const inventory = { labs: rows.map((row) => ({ labPath: row.labPath })) };
  const missing = findMissingMatrixLabs(inventory, [
    'labs/day-1/00-setup.md',
    'labs/day-1/03-core-workflow.md',
    'labs/day-1/99-missing-from-matrix.md',
  ]);
  assert.deepEqual(missing, ['labs/day-1/99-missing-from-matrix.md']);
});

test('buildInventory rejects contracted labs missing from the matrix', () => {
  const root = fixtureRepo();
  assert.throws(
    () => buildInventory({
      repoRoot: root,
      contractedLabs: ['labs/day-1/00-setup.md', 'labs/day-1/99-missing-from-matrix.md'],
    }),
    /missing row\(s\) for contracted lab\(s\): labs\/day-1\/99-missing-from-matrix\.md/,
  );
});

test('buildInventory derives duration, cleanup, and automation tier', () => {
  const root = fixtureRepo();
  const contracted = [
    'labs/day-1/00-setup.md',
    'labs/day-1/03-core-workflow.md',
    'labs/day-1/11-taco-landscape.md',
  ];
  const inventory = buildInventory({ repoRoot: root, contractedLabs: contracted });
  assert.equal(inventory.sourceOfTruth, MATRIX_PATH);
  assert.equal(inventory.labs.length, 3);

  const setup = inventory.labs.find((lab) => lab.id === 'day-1/00-setup');
  assert.equal(setup.automationTier, 'mixed');
  assert.equal(setup.estimatedDurationMin, 20);
  assert.match(setup.cleanupCommand, /task lab:down/);

  const paper = inventory.labs.find((lab) => lab.id === 'day-1/11-taco-landscape');
  assert.equal(paper.automationTier, 'paper');
});

test('renderInventory is stable JSON and real repo covers every contracted lab', () => {
  const inventory = buildInventory({ repoRoot: REPO_ROOT, contractedLabs: CONTRACTED_LABS });
  assert.equal(inventory.labs.length, CONTRACTED_LABS.length);
  const missing = findMissingMatrixLabs(inventory, CONTRACTED_LABS);
  assert.deepEqual(missing, [], `matrix missing rows for: ${missing.join(', ')}`);

  const rendered = renderInventory(inventory);
  assert.match(rendered, /"schemaVersion": 1/);
  assert.equal(rendered.endsWith('\n'), true);

  const committed = JSON.parse(readFileSync(join(REPO_ROOT, INVENTORY_PATH), 'utf8'));
  assert.deepEqual(committed, JSON.parse(rendered));
});
