#!/usr/bin/env node
'use strict';

const { execFileSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const REPO_ROOT = process.cwd();
const TEST_PATTERN = /\.(test|spec)\.[cm]?[jt]sx?$/;
const SOURCE_PATTERN = /\.[cm]?[jt]sx?$/;

function parseArgs(argv) {
  const parsed = { base: null, head: null };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--base') {
      parsed.base = argv[i + 1] ?? null;
      i += 1;
    } else if (token === '--head') {
      parsed.head = argv[i + 1] ?? null;
      i += 1;
    } else if (token.startsWith('--base=')) {
      parsed.base = token.slice('--base='.length);
    } else if (token.startsWith('--head=')) {
      parsed.head = token.slice('--head='.length);
    }
  }
  return parsed;
}

function isRefLike(ref) {
  return typeof ref === 'string' && /^[0-9a-zA-Z._\/-]{4,255}$/.test(ref);
}

function block(message) {
  process.stderr.write(`d6-check: BLOCK ${message}\n`);
  process.exit(1);
}

function invalid(message) {
  process.stderr.write(`d6-check: invalid invocation - ${message}\n`);
  process.exit(2);
}

function degrade(reason) {
  process.stdout.write(`d6-check: dependents not computed (${reason})\n`);
  process.exit(0);
}

function warn(message) {
  process.stdout.write(`d6-check: WARN ${message}\n`);
}

function git(args, options = {}) {
  return execFileSync('git', args, {
    encoding: 'utf8',
    cwd: options.cwd || REPO_ROOT,
    stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
}

function tryGit(args, options = {}) {
  try {
    return { ok: true, out: git(args, options) };
  } catch (error) {
    return { ok: false, error };
  }
}

function commandExists(command, probeArgs) {
  const result = spawnSync(command, probeArgs, { stdio: 'ignore' });
  return !result.error && result.status === 0;
}

function detectStack() {
  if (fs.existsSync(path.join(REPO_ROOT, 'package.json'))) {
    return 'jsts';
  }
  if (fs.existsSync(path.join(REPO_ROOT, 'go.mod'))) {
    return 'go';
  }
  if (
    fs.existsSync(path.join(REPO_ROOT, 'pyproject.toml')) ||
    fs.existsSync(path.join(REPO_ROOT, 'setup.py')) ||
    fs.existsSync(path.join(REPO_ROOT, 'setup.cfg'))
  ) {
    return 'python';
  }
  return null;
}

function madgeGraph(rootDir) {
  const result = spawnSync(
    'npx',
    ['--no-install', 'madge', '--json', '.'],
    { cwd: rootDir, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }
  );
  if (result.error || result.status !== 0) {
    return null;
  }
  try {
    const parsed = JSON.parse(result.stdout);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed;
    }
    return null;
  } catch (error) {
    return null;
  }
}

function reverseClosure(forwardGraph, seeds) {
  const reverse = new Map();
  for (const [file, deps] of Object.entries(forwardGraph)) {
    if (!Array.isArray(deps)) {
      continue;
    }
    for (const dep of deps) {
      if (!reverse.has(dep)) {
        reverse.set(dep, new Set());
      }
      reverse.get(dep).add(file);
    }
  }
  const seen = new Set();
  const queue = seeds.filter((seed) => forwardGraph[seed] !== undefined || reverse.has(seed));
  while (queue.length > 0) {
    const current = queue.shift();
    const dependents = reverse.get(current);
    if (!dependents) {
      continue;
    }
    for (const dependent of dependents) {
      if (!seen.has(dependent)) {
        seen.add(dependent);
        queue.push(dependent);
      }
    }
  }
  return seen;
}

function findTestsFor(dependent) {
  if (TEST_PATTERN.test(dependent)) {
    return fs.existsSync(path.join(REPO_ROOT, dependent)) ? [dependent] : [];
  }
  if (!SOURCE_PATTERN.test(dependent)) {
    return [];
  }
  const dir = path.dirname(dependent);
  const ext = path.extname(dependent);
  const base = path.basename(dependent, ext);
  const candidates = [];
  for (const kind of ['test', 'spec']) {
    for (const testExt of ['.js', '.jsx', '.ts', '.tsx', '.cjs', '.mjs']) {
      candidates.push(path.join(dir, `${base}.${kind}${testExt}`));
      candidates.push(path.join(dir, '__tests__', `${base}.${kind}${testExt}`));
      candidates.push(path.join(dir, '__tests__', `${base}${testExt}`));
    }
  }
  return candidates.filter((candidate) => fs.existsSync(path.join(REPO_ROOT, candidate)));
}

function runJsTests(testFiles) {
  const result = spawnSync('npm', ['test', '--', ...testFiles], {
    cwd: REPO_ROOT,
    stdio: 'inherit',
  });
  if (result.error) {
    degrade(`test runner not invokable: ${result.error.message}`);
  }
  return result.status === 0;
}

function handleJsTs(mergeBase, headSha, changedFiles) {
  const jsChanged = changedFiles.filter((file) => SOURCE_PATTERN.test(file));
  if (jsChanged.length === 0) {
    degrade('no JS/TS files changed');
  }
  if (!commandExists('npx', ['--no-install', 'madge', '--version'])) {
    degrade('madge not available');
  }

  const headGraph = madgeGraph(REPO_ROOT);
  if (!headGraph) {
    degrade('madge failed on head tree');
  }
  const headDependents = reverseClosure(headGraph, jsChanged);

  const worktreeDir = fs.mkdtempSync(path.join(os.tmpdir(), 'd6-base-'));
  let baseDependents = new Set();
  const added = tryGit(['worktree', 'add', '--detach', '--force', worktreeDir, mergeBase]);
  try {
    if (added.ok) {
      const baseGraph = madgeGraph(worktreeDir);
      if (baseGraph) {
        baseDependents = reverseClosure(baseGraph, jsChanged);
      }
    }
  } finally {
    tryGit(['worktree', 'remove', '--force', worktreeDir]);
    if (fs.existsSync(worktreeDir)) {
      fs.rmSync(worktreeDir, { recursive: true, force: true });
    }
  }

  const newDependents = [...headDependents].filter((file) => !baseDependents.has(file));
  if (newDependents.length === 0) {
    degrade('no new dependents introduced by this change');
  }

  const testFiles = new Set();
  const untested = [];
  for (const dependent of newDependents) {
    const tests = findTestsFor(dependent);
    if (tests.length === 0) {
      untested.push(dependent);
    } else {
      for (const test of tests) {
        testFiles.add(test);
      }
    }
  }

  for (const dependent of untested) {
    warn(`new dependent has no test: ${dependent}`);
  }

  if (testFiles.size === 0) {
    process.stdout.write('d6-check: no tests mapped to new dependents; nothing to run\n');
    process.exit(0);
  }

  const ordered = [...testFiles];
  process.stdout.write(`d6-check: running ${ordered.length} test file(s) for new dependents\n`);
  if (!runJsTests(ordered)) {
    block(`tests failed for new dependents: ${ordered.join(', ')}`);
  }
  process.stdout.write('d6-check: new dependents pass on head\n');
  process.exit(0);
}

function main() {
  const { base, head } = parseArgs(process.argv.slice(2));
  if (!base || !head) {
    invalid('usage: d6-check.cjs --base <ref> --head <ref>');
  }
  if (!isRefLike(base) || !isRefLike(head)) {
    invalid('--base and --head must be valid git refs');
  }

  const baseResolved = tryGit(['rev-parse', '--verify', `${base}^{commit}`]);
  const headResolved = tryGit(['rev-parse', '--verify', `${head}^{commit}`]);
  if (!baseResolved.ok || !headResolved.ok) {
    degrade('base or head ref not resolvable in this repository');
  }

  const mergeBaseResult = tryGit(['merge-base', baseResolved.out, headResolved.out]);
  const mergeBase = mergeBaseResult.ok ? mergeBaseResult.out : baseResolved.out;

  const diffResult = tryGit(['diff', '--name-only', mergeBase, headResolved.out]);
  if (!diffResult.ok) {
    degrade('git diff against merge base failed');
  }
  const changedFiles = diffResult.out.split('\n').map((line) => line.trim()).filter(Boolean);
  if (changedFiles.length === 0) {
    degrade('no changed files between merge base and head');
  }

  const stack = detectStack();
  if (stack === 'jsts') {
    handleJsTs(mergeBase, headResolved.out, changedFiles);
    return;
  }
  degrade(`no supported import grapher for this stack (detected: ${stack || 'unknown'})`);
}

main();
