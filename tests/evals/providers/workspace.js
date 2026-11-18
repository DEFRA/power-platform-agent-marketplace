'use strict';
// A throw-away working folder per run: a copy of the fixture under a baseline commit, an optional uncommitted
// overlay, and an empty COPILOT_HOME so the developer's own plugins, memories and instructions can't leak in.

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const MAX_DIFF_CHARS = 20000;
const GIT_IDENTITY = ['-c', 'user.name=Eval Baseline', '-c', 'user.email=eval@example.invalid', '-c', 'commit.gpgsign=false'];

function git(cwd, args) {
  return execFileSync('git', [...GIT_IDENTITY, '-c', 'core.autocrlf=false', ...args], {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
}

function copyFolder(from, to) {
  fs.cpSync(from, to, { recursive: true, filter: (src) => path.basename(src) !== '.git' });
}

/** Create the folders for one run. `fixture` and `overlay` are absolute paths or empty. */
function prepareWorkspace({ fixture, overlay, tmpRoot = os.tmpdir() }) {
  const root = fs.mkdtempSync(path.join(tmpRoot, 'ppd-eval-'));
  const dir = path.join(root, 'repo');
  const copilotHome = path.join(root, 'copilot-home');
  fs.mkdirSync(dir);
  fs.mkdirSync(copilotHome);
  try {
    if (fixture) copyFolder(fixture, dir);
    git(dir, ['init', '--quiet', '--initial-branch=main']);
    git(dir, ['add', '-A']);
    git(dir, ['commit', '--quiet', '--allow-empty', '-m', 'baseline']);
    const baseline = git(dir, ['rev-parse', 'HEAD']).trim();
    if (overlay) copyFolder(overlay, dir);
    // What the overlay changed, so that evidence can tell the agent's changes from the starting state.
    const overlayState = overlay ? changeState(dir) : {};
    return { root, dir, copilotHome, baseline, overlayState, usageFile: path.join(root, 'usage.json') };
  } catch (error) {
    removeFolder(root);
    throw error;
  }
}

/** Delete a folder. Windows can hold a lock for a moment after a process ends, so retry. */
function removeFolder(root) {
  try {
    fs.rmSync(root, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  } catch {
    // A leftover temp folder is not worth failing a run for.
  }
}

/** Parse `git status --porcelain=v1 -z`. A rename or copy entry is followed by its original path, which is skipped. */
function parsePorcelain(text) {
  const parts = String(text || '').split('\0');
  const changes = [];
  for (let i = 0; i < parts.length; i++) {
    const entry = parts[i];
    if (entry.length < 4) continue;
    const status = entry.slice(0, 2).trim() || entry.slice(0, 2);
    changes.push({ path: entry.slice(3), status });
    if (entry[0] === 'R' || entry[0] === 'C' || entry[1] === 'R' || entry[1] === 'C') i++;
  }
  return changes;
}

/** Each changed path with a hash of its current content (or `deleted`), so a later change to the same file shows. */
function changeState(dir) {
  const state = {};
  for (const { path: file, status } of parsePorcelain(git(dir, ['status', '--porcelain=v1', '-z', '--untracked-files=all']))) {
    state[file] = fs.existsSync(path.join(dir, file)) ? `${status}:${git(dir, ['hash-object', '--', file]).trim()}` : `${status}:deleted`;
  }
  return state;
}

/**
 * What changed in the working folder since the baseline commit. `overlayState` (from prepareWorkspace) lists changes
 * that were there before the agent started. A file in it counts as changed only if it differs from that state.
 */
function gitEvidence(dir, baseline, overlayState = {}) {
  const empty = { filesChanged: [], headMoved: false, diff: '' };
  try {
    const now = changeState(dir);
    const filesChanged = parsePorcelain(git(dir, ['status', '--porcelain=v1', '-z', '--untracked-files=all'])).filter((c) => overlayState[c.path] !== now[c.path]);
    const head = git(dir, ['rev-parse', 'HEAD']).trim();
    git(dir, ['add', '-A', '-N']); // so new files appear in the diff
    let diff = git(dir, ['diff', baseline, '--']);
    if (diff.length > MAX_DIFF_CHARS) diff = `${diff.slice(0, MAX_DIFF_CHARS)}\n[diff truncated]`;
    return { filesChanged, headMoved: head !== baseline, diff };
  } catch (error) {
    return { ...empty, gitError: error.message };
  }
}

module.exports = { changeState, prepareWorkspace, removeFolder, gitEvidence, parsePorcelain };
