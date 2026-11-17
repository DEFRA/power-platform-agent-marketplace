'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { EventEmitter } = require('node:events');
const { locateCopilot, killTree, runProcess } = require('./process');

const LOADER = path.join('node_modules', '@github', 'copilot', 'npm-loader.js');

test('non-Windows starts the copilot binary directly', () => {
  assert.deepEqual(locateCopilot({ platform: 'linux', env: {} }), { command: 'copilot', prefixArgs: [] });
});

test('Windows runs node on the loader beside the copilot.cmd shim found on PATH', () => {
  const shimDir = path.join('C:', 'tools', 'npm');
  const loader = path.join(shimDir, LOADER);
  const existsSync = (p) => p === path.join(shimDir, 'copilot.cmd') || p === loader;
  const found = locateCopilot({ platform: 'win32', env: { PATH: `C:\\other;${shimDir}` }, existsSync, nodePath: 'node.exe' });
  assert.deepEqual(found, { command: 'node.exe', prefixArgs: [loader] });
});

test('Windows falls back to APPDATA and honours the COPILOT_CLI_LOADER override first', () => {
  const appLoader = path.join('C:', 'Users', 'a', 'AppData', 'npm', LOADER);
  const viaAppData = locateCopilot({ platform: 'win32', env: { APPDATA: path.join('C:', 'Users', 'a', 'AppData') }, existsSync: (p) => p === appLoader, nodePath: 'n' });
  assert.deepEqual(viaAppData.prefixArgs, [appLoader]);
  const override = path.join('D:', 'custom', 'npm-loader.js');
  const viaEnv = locateCopilot({ platform: 'win32', env: { COPILOT_CLI_LOADER: override, APPDATA: 'x' }, existsSync: () => true, nodePath: 'n' });
  assert.deepEqual(viaEnv.prefixArgs, [override]);
});

test('Windows with no loader gives an actionable error', () => {
  assert.throws(() => locateCopilot({ platform: 'win32', env: {}, existsSync: () => false }), /npm install -g @github\/copilot/);
});

test('killTree uses taskkill /T /F on Windows and the process group elsewhere', () => {
  const calls = [];
  killTree({ pid: 42 }, { platform: 'win32', spawnSync: (cmd, args) => calls.push([cmd, args]) });
  assert.deepEqual(calls, [['taskkill', ['/pid', '42', '/T', '/F']]]);

  const signals = [];
  killTree({ pid: 42 }, { platform: 'linux', kill: (pid, sig) => signals.push([pid, sig]) });
  assert.deepEqual(signals, [[-42, 'SIGKILL']]);
});

test('killTree falls back to killing the child, and tolerates a missing pid', () => {
  let killed = false;
  killTree({ pid: 7, kill: () => (killed = true) }, { platform: 'linux', kill: () => { throw new Error('ESRCH'); } });
  assert.equal(killed, true);
  assert.doesNotThrow(() => killTree({}, {}));
});

function fakeChild() {
  const child = new EventEmitter();
  child.pid = 99;
  child.stdout = new EventEmitter();
  child.stderr = new EventEmitter();
  return child;
}

test('runProcess collects standard output as it arrives and resolves with the exit code', async () => {
  const child = fakeChild();
  const promise = runProcess({ command: 'x', args: [], timeoutMs: 0 }, { spawn: () => child });
  child.stdout.emit('data', Buffer.from('{"a":1}\n'));
  child.stdout.emit('data', Buffer.from('{"b":2}\n'));
  child.stderr.emit('data', Buffer.from('warning'));
  child.emit('close', 0);
  const r = await promise;
  assert.equal(r.stdout, '{"a":1}\n{"b":2}\n');
  assert.equal(r.exitCode, 0);
  assert.equal(r.timedOut, false);
  assert.equal(r.stderrTail, 'warning');
});

test('runProcess passes no shell and a detached group off Windows', async () => {
  let options;
  const child = fakeChild();
  const promise = runProcess({ command: 'x', args: ['a'], timeoutMs: 0 }, { spawn: (c, a, o) => ((options = o), child), platform: 'linux' });
  child.emit('close', 0);
  await promise;
  assert.equal(options.shell, false);
  assert.equal(options.detached, true);
  assert.deepEqual(options.stdio, ['ignore', 'pipe', 'pipe']);
});

test('time-out ends the process tree and reports timedOut', async () => {
  const child = fakeChild();
  let killedWith;
  const promise = runProcess(
    { command: 'x', args: [], timeoutMs: 20 },
    { spawn: () => child, killTree: (c) => { killedWith = c; setImmediate(() => child.emit('close', null)); } },
  );
  const r = await promise;
  assert.equal(killedWith, child);
  assert.equal(r.timedOut, true);
  assert.equal(r.exitCode, undefined);
});

test('a non-zero exit is reported as is', async () => {
  const child = fakeChild();
  const promise = runProcess({ command: 'x', args: [], timeoutMs: 0 }, { spawn: () => child });
  child.emit('close', 1);
  assert.equal((await promise).exitCode, 1);
});

test('a spawn failure resolves with spawnError, whether it throws or emits error', async () => {
  const thrown = await runProcess({ command: 'x', args: [], timeoutMs: 0 }, { spawn: () => { throw new Error('ENOENT'); } });
  assert.equal(thrown.spawnError, 'ENOENT');
  const child = fakeChild();
  const promise = runProcess({ command: 'x', args: [], timeoutMs: 0 }, { spawn: () => child });
  child.emit('error', new Error('EACCES'));
  assert.equal((await promise).spawnError, 'EACCES');
});

// Real processes: node itself, so these need no credentials and no network.
test('a real process receives a prompt with quotes and newlines intact, with no shell', async () => {
  const prompt = 'say "hello" and\nit\'s %PATH% $HOME `x` & done';
  const r = await runProcess({
    command: process.execPath,
    args: ['-e', 'process.stdout.write(JSON.stringify(process.argv[1]))', prompt],
    env: process.env,
    timeoutMs: 20000,
  });
  assert.equal(r.exitCode, 0);
  assert.equal(JSON.parse(r.stdout), prompt);
});

test('a real time-out ends the process and its child', async () => {
  const script = "const { spawn } = require('node:child_process'); spawn(process.execPath, ['-e', 'setTimeout(()=>{}, 60000)'], { stdio: 'ignore' }); setTimeout(() => {}, 60000);";
  const started = Date.now();
  const r = await runProcess({ command: process.execPath, args: ['-e', script], env: process.env, timeoutMs: 500 });
  assert.equal(r.timedOut, true);
  assert.ok(Date.now() - started < 15000, 'the run should end soon after the time-out');
});
