'use strict';
// Uses real git in temporary folders. No credentials and no network.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { prepareWorkspace, removeFolder, gitEvidence, parsePorcelain } = require('./workspace');

function tempFolder(files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ppd-eval-test-'));
  for (const [name, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(dir, name)), { recursive: true });
    fs.writeFileSync(path.join(dir, name), content);
  }
  return dir;
}

test('parsePorcelain reads modified, untracked and renamed entries', () => {
  const text = ' M a.txt\0?? b.txt\0R  new.txt\0old.txt\0A  c.txt\0';
  assert.deepEqual(parsePorcelain(text), [
    { path: 'a.txt', status: 'M' },
    { path: 'b.txt', status: '??' },
    { path: 'new.txt', status: 'R' },
    { path: 'c.txt', status: 'A' },
  ]);
  assert.deepEqual(parsePorcelain(''), []);
});

test('a workspace is a baseline-committed copy of the fixture, with an overlay left uncommitted', () => {
  const fixture = tempFolder({ 'README.md': '# Fixture\n', 'src/a.txt': 'a\n', '.git/ignored': 'x' });
  const overlay = tempFolder({ 'src/a.txt': 'changed\n', 'notes.md': 'new\n' });
  const ws = prepareWorkspace({ fixture, overlay });
  try {
    assert.match(ws.baseline, /^[0-9a-f]{40}$/);
    assert.ok(fs.existsSync(path.join(ws.copilotHome)), 'an empty COPILOT_HOME exists');
    assert.deepEqual(fs.readdirSync(ws.copilotHome), []);
    assert.ok(!fs.existsSync(path.join(ws.dir, '.git', 'ignored')), 'the fixture .git is not copied');
    const e = gitEvidence(ws.dir, ws.baseline);
    assert.deepEqual(e.filesChanged.map((c) => c.path).sort(), ['notes.md', 'src/a.txt']);
    assert.equal(e.headMoved, false);
    assert.match(e.diff, /\+changed/);
    assert.match(e.diff, /notes\.md/, 'untracked files appear in the diff');
  } finally {
    removeFolder(ws.root);
    removeFolder(fixture);
    removeFolder(overlay);
  }
  assert.ok(!fs.existsSync(ws.root), 'the temporary folder is deleted');
});

test('an empty fixture still gets a baseline commit', () => {
  const ws = prepareWorkspace({});
  try {
    assert.match(ws.baseline, /^[0-9a-f]{40}$/);
    assert.deepEqual(gitEvidence(ws.dir, ws.baseline), { filesChanged: [], headMoved: false, diff: '' });
  } finally {
    removeFolder(ws.root);
  }
});

test('edits, new files and a moved HEAD are all evidence', () => {
  const fixture = tempFolder({ 'a.txt': 'a\n' });
  const ws = prepareWorkspace({ fixture });
  try {
    fs.writeFileSync(path.join(ws.dir, 'a.txt'), 'edited\n');
    fs.writeFileSync(path.join(ws.dir, 'b.txt'), 'new\n');
    const { execFileSync } = require('node:child_process');
    execFileSync('git', ['-c', 'user.name=x', '-c', 'user.email=x@example.invalid', 'commit', '-qam', 'agent commit'], { cwd: ws.dir });
    const e = gitEvidence(ws.dir, ws.baseline);
    assert.equal(e.headMoved, true);
    assert.deepEqual(e.filesChanged.map((c) => c.path), ['b.txt']);
    assert.match(e.diff, /\+edited/);
  } finally {
    removeFolder(ws.root);
    removeFolder(fixture);
  }
});

test('a long diff is truncated', () => {
  const fixture = tempFolder({ 'a.txt': 'a\n' });
  const ws = prepareWorkspace({ fixture });
  try {
    fs.writeFileSync(path.join(ws.dir, 'big.txt'), 'x\n'.repeat(30000));
    const e = gitEvidence(ws.dir, ws.baseline);
    assert.match(e.diff, /\[diff truncated\]$/);
    assert.ok(e.diff.length < 21000);
  } finally {
    removeFolder(ws.root);
    removeFolder(fixture);
  }
});

test('git evidence from a folder that is not a repository reports the error instead of throwing', () => {
  const dir = tempFolder({ 'a.txt': 'a' });
  try {
    const e = gitEvidence(path.join(dir, 'missing'), 'abc');
    assert.ok(e.gitError);
    assert.deepEqual(e.filesChanged, []);
  } finally {
    removeFolder(dir);
  }
});

test('changes that came from the overlay are not reported as changes made by the run, but a further change to them is', () => {
  const fixture = tempFolder({ 'a.txt': 'a', 'b.txt': 'b' });
  const overlay = tempFolder({ 'a.txt': 'overlaid', 'new.md': 'new' });
  const ws = prepareWorkspace({ fixture, overlay });
  const plain = prepareWorkspace({});
  try {
    assert.deepEqual(Object.keys(ws.overlayState).sort(), ['a.txt', 'new.md']);
    assert.deepEqual(gitEvidence(ws.dir, ws.baseline, ws.overlayState).filesChanged, [], 'the overlay alone is no change');
    fs.writeFileSync(path.join(ws.dir, 'a.txt'), 'edited again');
    fs.writeFileSync(path.join(ws.dir, 'b.txt'), 'edited');
    fs.rmSync(path.join(ws.dir, 'new.md'));
    const changed = gitEvidence(ws.dir, ws.baseline, ws.overlayState).filesChanged.map((c) => c.path).sort();
    assert.deepEqual(changed, ['a.txt', 'b.txt', 'new.md'], 'a changed overlay file, a changed fixture file and a deleted overlay file');
    assert.deepEqual(plain.overlayState, {}, 'no overlay, no state');
  } finally {
    removeFolder(ws.root);
    removeFolder(plain.root);
    removeFolder(fixture);
    removeFolder(overlay);
  }
});
