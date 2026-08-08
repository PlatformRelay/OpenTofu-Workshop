#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export const DAY_1_LABS = [
  'labs/day-1/00-setup.md',
  'labs/day-1/01-iac-fork.md',
  'labs/day-1/02-hcl-blocks.md',
  'labs/day-1/03-core-workflow.md',
  'labs/day-1/04-state.md',
  'labs/day-1/05-state-encryption.md',
  'labs/day-1/06-variables.md',
  'labs/day-1/07-modules.md',
  'labs/day-1/08-naming-labels.md',
  'labs/day-1/09-best-practices.md',
  'labs/day-1/10-differentiators.md',
  'labs/day-1/11-taco-landscape.md',
  'labs/day-1/15-conditions-checks.md',
];

export const DAY_2_LABS = [
  'labs/day-2/12-testing-pyramid.md',
  'labs/day-2/13-static-analysis.md',
  'labs/day-2/14-security-scanners.md',
  'labs/day-2/16-tofu-test.md',
  'labs/day-2/17-mocking.md',
  'labs/day-2/18-terratest-cost.md',
  'labs/day-2/19-testing-cicd.md',
];

export const DAY_3_LABS = [
  'labs/day-3/20-why-terramate.md',
  'labs/day-3/21-stacks.md',
  'labs/day-3/22-codegen.md',
  'labs/day-3/23-orchestration.md',
  'labs/day-3/24-change-detection.md',
  'labs/day-3/25-terramate-ci-cloud.md',
  'labs/day-3/26-capstone.md',
  'labs/day-3/27-terragrunt-comparison.md',
  'labs/day-3/28-ecosystem-tooling.md',
];

export const CONTRACTED_LABS = [...DAY_1_LABS, ...DAY_2_LABS, ...DAY_3_LABS];

const REQUIRED_SOLUTION_HEADINGS = [
  'Guided solutions',
  'Expected state / output',
  'Explanation',
  'Troubleshooting and recovery',
  'Stretch solution',
];

function section(markdown, heading, level = 2) {
  const marker = `${'#'.repeat(level)} ${heading}`;
  const body = [];
  let collecting = false;
  let inFence = false;
  for (const line of markdown.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) {
      if (collecting) body.push(line);
      inFence = !inFence;
      continue;
    }
    if (!inFence && line.trim() === marker) {
      collecting = true;
      continue;
    }
    if (collecting && !inFence) {
      const next = line.match(/^(#{1,6})\s+/);
      if (next && next[1].length <= level) break;
    }
    if (collecting) body.push(line);
  }
  return body.join('\n').trim();
}

function normalized(markdown) {
  return markdown
    .replace(/[`*_#>]/g, '')
    .replace(/-/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function words(markdown) {
  return normalized(markdown).match(/[\p{Letter}\p{Number}]+/gu) ?? [];
}

function executableFences(markdown) {
  return [...markdown.matchAll(/```(bash|sh|hcl|console|yaml|text)\s+([\s\S]*?)```/g)]
    .map((match) => ({ language: match[1], body: match[2] }));
}

function hasSubstantiveExecutableFence(markdown) {
  return executableFences(markdown).some(({ language, body }) => {
    if (language === 'hcl') {
      return /(?:^|\n)\s*(?:terraform|resource|module|provider|variable|output|data)\b/m.test(body) &&
        words(body).length >= 6;
    }
    if (language === 'yaml') {
      return /(?:^|\n)\s*(?:apiVersion|kind):\s*\S+/m.test(body) && words(body).length >= 6;
    }
    const commands = body
      .split('\n')
      .map((line) => line.replace(/^\s*\$\s*/, '').trim())
      .filter((line) => line && !line.startsWith('#') && !/^(?:echo|printf)\b/.test(line) &&
        !/^(?:true|false|:)\s*$/.test(line));
    return commands.some((line) => {
      const wc = words(line).length;
      return (wc >= 2 || /\bcd\s+\.\./.test(line)) &&
        /(?:^|[;&|]\s*|\s)(?:tofu|task|terraform|terramate|tm|curl|docker|infracost|trivy|checkov|tfsec|terragrunt|bash|cd|rm|grep|cat|ls|git)\b/.test(line);
    });
  });
}

function hasObservableResult(markdown) {
  return words(markdown).length >= 6 &&
    /ready|running|cached|exists|absent|present|returns?|prints?|output|status|count|address|endpoint|http|https|uid|digest|component|resource|replica|match|field|path|succeeds?|fails?|reaches?|appears?|disappears?|complete|destroyed|added|changed|plan|apply|init|validate|encrypted|decrypted|bucket|state/i.test(markdown);
}

function hasCausalAccount(markdown) {
  return words(markdown).length >= 10 &&
    /because|therefore|\bso\b|when|while|due|caus|means|allows?|permits?|requires?|retains?|removes?|preserves?|invalidates?|tracks?|supplies?|trades?|asks?|ensures?|keeps?|stores?|reads?|writes?|binds?|wires?|orders?|filters?/i.test(markdown);
}

function hasConcreteCorrectiveCommand(markdown) {
  const code = [
    ...executableFences(markdown).map(({ body }) => body),
    ...[...markdown.matchAll(/`([^`]+)`/g)].map((match) => match[1]),
  ];
  return /restore|reapply|rerun|remove|delete|undo|patch|reset|retry|fix|recover|destroy|panic|clean/i.test(markdown) &&
    code.some((snippet) => {
      const wc = words(snippet).length;
      return (wc >= 2 || /\bcd\s+\.\./.test(snippet)) &&
        /(?:tofu\s+(?:destroy|apply|init|plan|validate|test)|task\s+(?:lab:down|lab:reset|verify)|git\s+restore|(?:^|\s)rm\s+-|cd\s+\.\.)/.test(snippet);
    });
}

function headings(markdown) {
  const result = new Map();
  let inFence = false;
  markdown.split('\n').forEach((line, index) => {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      return;
    }
    if (inFence) return;
    const match = line.match(/^##\s+(.+?)\s*#*\s*$/);
    if (match && !result.has(match[1])) result.set(match[1], index + 1);
  });
  return result;
}

function headingSlugs(markdown) {
  const slugs = new Set();
  let inFence = false;
  for (const line of markdown.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    const match = line.match(/^#{1,6}\s+(.+?)\s*#*\s*$/);
    if (match) {
      slugs.add(match[1].trim().toLowerCase().replace(/`([^`]*)`/g, '$1')
        .replace(/[^\p{Letter}\p{Number}_ -]/gu, '').replace(/ /g, '-'));
    }
  }
  return slugs;
}

function unsafeCommands(markdown) {
  const errors = [];
  markdown.split('\n').forEach((line, index) => {
    const lineNumber = index + 1;
    if (/\brm\s+-(?=[a-z]*r)(?=[a-z]*f)[a-z]+\s+(?:\/(?:\s|[`'"]|$)|\/\*|~(?:\/|\s|[`'"]|$)|\$\{?HOME\}?|\.\.\/\.\.)/i.test(line)) {
      errors.push(`line ${lineNumber}: host-wide destructive command`);
    }
  });
  return errors;
}

export function auditLabInventory(repoRoot = REPO_ROOT) {
  const errors = [];
  const contracted = new Set(CONTRACTED_LABS);
  for (const day of ['day-1', 'day-2', 'day-3']) {
    const dir = resolve(repoRoot, 'labs', day);
    if (!existsSync(dir)) continue;
    for (const name of readdirSync(dir).filter((file) =>
      file.endsWith('.md') && !file.endsWith('.solution.md'))) {
      const path = `labs/${day}/${name}`;
      if (!contracted.has(path)) {
        errors.push(`${path}: participant lab must be listed in CONTRACTED_LABS or explicitly deferred`);
      }
    }
  }
  return errors;
}

function isPaperLab(markdown) {
  return /`paper ✓`/i.test(markdown) || /paper lab/i.test(markdown);
}

export function auditLab(labPath) {
  const absoluteLab = resolve(labPath);
  const display = relative(REPO_ROOT, absoluteLab) || absoluteLab;
  const errors = [];
  if (!existsSync(absoluteLab)) return [`${display}: lab file does not exist`];

  const markdown = readFileSync(absoluteLab, 'utf8');
  const paper = isPaperLab(markdown);
  if (!/^# Lab \d{2}\s+—\s+\S.+$/u.test(markdown.split('\n')[0])) {
    errors.push(`${display}: missing lab title`);
  }

  errors.push(...unsafeCommands(markdown).map((error) => `${display}: ${error}`));

  const solutionPath = absoluteLab.replace(/\.md$/, '.solution.md');
  const solutionName = solutionPath.split('/').at(-1);
  if (!existsSync(solutionPath)) {
    errors.push(`${display}: missing sibling solution: ${solutionName}`);
    return errors;
  }

  const solution = readFileSync(solutionPath, 'utf8');
  errors.push(...unsafeCommands(solution).map((error) =>
    `${relative(REPO_ROOT, solutionPath)}: ${error}`));

  const solutionHeadings = headings(solution);
  for (const heading of REQUIRED_SOLUTION_HEADINGS) {
    if (!solutionHeadings.has(heading)) {
      errors.push(`${relative(REPO_ROOT, solutionPath)}: missing heading: ${heading}`);
    }
  }

  const slugs = headingSlugs(solution);
  if (!slugs.has('guided-solutions')) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: missing #guided-solutions anchor`);
  }
  if (!slugs.has('stretch-solution')) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: missing #stretch-solution anchor`);
  }

  const guidedSolution = section(solution, 'Guided solutions');
  const expectedState = section(solution, 'Expected state / output');
  const explanation = section(solution, 'Explanation');
  const troubleshooting = section(solution, 'Troubleshooting and recovery');
  const stretchSolution = section(solution, 'Stretch solution');

  if (!paper && !hasSubstantiveExecutableFence(guidedSolution)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Guided solutions need substantive commands or HCL`);
  } else if (paper && words(guidedSolution).length < 40) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Guided solutions need substantive scenario coverage`);
  }
  if (!hasObservableResult(expectedState)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Expected state / output needs an observable result`);
  }
  if (!hasCausalAccount(explanation)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Explanation needs a causal account`);
  }
  if (!hasConcreteCorrectiveCommand(troubleshooting)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Troubleshooting needs a concrete corrective command`);
  }

  const stretchCommands = section(stretchSolution, 'Commands / manifest', 3);
  const stretchExpected = section(stretchSolution, 'Expected state / output', 3);
  const stretchExplanation = section(stretchSolution, 'Explanation', 3);
  if (!paper && !hasSubstantiveExecutableFence(stretchCommands || stretchSolution)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Stretch solution needs substantive commands or HCL`);
  } else if (paper && words(stretchSolution).length < 20) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Stretch solution needs substantive guidance`);
  }
  if (!hasObservableResult(stretchExpected || stretchSolution)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Stretch expected state / output needs an observable result`);
  }
  if (!hasCausalAccount(stretchExplanation || stretchSolution)) {
    errors.push(`${relative(REPO_ROOT, solutionPath)}: Stretch explanation needs a causal account`);
  }

  return errors;
}

export function auditLabs(paths = CONTRACTED_LABS.map((path) => resolve(REPO_ROOT, path))) {
  return [...auditLabInventory(), ...paths.flatMap(auditLab)];
}

export function auditContractDocumentation(repoRoot = REPO_ROOT) {
  const errors = [];
  const adrDir = resolve(repoRoot, 'docs/decisions');
  if (!existsSync(adrDir)) {
    errors.push('docs/decisions: missing ADR directory');
    return errors;
  }

  let acceptedSiblingContract = false;
  for (const file of readdirSync(adrDir).filter((name) => /^\d{4}-.+\.md$/.test(name)).sort()) {
    const text = readFileSync(resolve(adrDir, file), 'utf8');
    const statusLine = text.split('\n').find((line) => /^\s*-\s*\*\*Status:\*\*/.test(line)) || '';
    const accepted = /\baccepted\b/i.test(statusLine) && !/\bsuperseded\b/i.test(statusLine);
    if (accepted && text.includes('NN-topic.solution.md')) {
      acceptedSiblingContract = true;
    }
  }
  if (!acceptedSiblingContract) {
    errors.push('docs/decisions: an accepted ADR must name the NN-topic.solution.md sibling contract');
  }

  const adrIndex = readFileSync(resolve(adrDir, 'README.md'), 'utf8');
  if (!adrIndex.includes('0013-sibling-lab-solutions.md')) {
    errors.push('docs/decisions/README.md: must list ADR 0013 sibling lab solutions');
  }

  return errors;
}

const invokedAsScript = process.argv[1] &&
  pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (invokedAsScript) {
  const docOnly = process.argv.includes('--docs');
  const extraPaths = process.argv.slice(2).filter((arg) =>
    !arg.startsWith('-') && (arg.includes('/') || arg.endsWith('.md')));
  const labPaths = extraPaths.length > 0
    ? extraPaths.map((path) => resolve(path))
    : CONTRACTED_LABS.map((path) => resolve(REPO_ROOT, path));

  const errors = docOnly
    ? auditContractDocumentation()
    : [...auditLabs(labPaths), ...auditContractDocumentation()];

  if (errors.length > 0) {
    console.error(`lab-contract: FAILED with ${errors.length} problem(s):`);
    for (const error of errors) console.error(`  ✗ ${error}`);
    process.exitCode = 1;
  } else {
    const count = docOnly ? 'documentation' : `${labPaths.length} participant labs and sibling solutions`;
    console.log(`lab-contract: OK — ${count}`);
  }
}
