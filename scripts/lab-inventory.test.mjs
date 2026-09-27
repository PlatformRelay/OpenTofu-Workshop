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
  readCleanupCommand,
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

test('readCleanupCommand skips navigation and env setup for the real command', () => {
  const lab = (body) => `# Lab\n\n## Cleanup / panic reset\n\n\`\`\`bash\n${body}\`\`\`\n\n## Stretch\n\n\`\`\`bash\ntofu apply\n\`\`\`\n`;
  // export before the destroy (Lab 08 recorded the export)
  assert.equal(
    readCleanupCommand(lab("export TF_VAR_state_passphrase='x'\ntofu -chdir=examples/demo destroy -auto-approve\n")),
    'tofu -chdir=examples/demo destroy -auto-approve',
  );
  // cd first (Labs 01-07 recorded the cd), inline comment dropped
  assert.equal(
    readCleanupCommand(lab('cd labs/day-1/01-iac-fork\ntofu destroy -auto-approve   # tear down\n')),
    'tofu destroy -auto-approve',
  );
  assert.equal(
    readCleanupCommand(lab('cd "$(git rev-parse --show-toplevel)"\ncd ../../..\ncd "$OLDPWD" 2>/dev/null || true\nrm -rf "${demo:-}"\n')),
    'rm -rf "${demo:-}"',
  );
  // a continuation line is one command (Lab 19 recorded "git restore -- \\")
  assert.equal(
    readCleanupCommand(lab('git restore -- \\\n  a/pipeline.yml \\\n  b/main.tf\ngit status --short\n')),
    'git restore -- a/pipeline.yml b/main.tf',
  );
  // navigation / env / inspection only -> no cleanup command, and never the Stretch fence
  assert.equal(readCleanupCommand(lab('cd ../../..\nexport X=1\ngit status --short\n')), null);
  assert.equal(readCleanupCommand('# Lab\n\n## Cleanup\n\nNothing to clean.\n\n## Stretch\n\n```bash\ntofu apply\n```\n'), null);
});

test('committed inventory records no navigation or env line as a cleanup command', () => {
  const committed = JSON.parse(readFileSync(join(REPO_ROOT, INVENTORY_PATH), 'utf8'));
  for (const lab of committed.labs) {
    if (lab.cleanupCommand == null) continue;
    assert.doesNotMatch(lab.cleanupCommand, /^(cd|export|pushd|popd|unset)\b|\\$/, `${lab.id}: ${lab.cleanupCommand}`);
  }
});
