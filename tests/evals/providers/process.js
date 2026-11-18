'use strict';
// Starting and ending Copilot CLI without a shell. Every collaborator is injectable, so the unit tests need no CLI.
// Tested on Windows only. The Linux and macOS paths (a direct spawn, and ending the process group) follow the
// documented behaviour of Node and are covered by unit tests with fakes, not by a real run.

const fs = require('node:fs');
const path = require('node:path');
const childProcess = require('node:child_process');

const LOADER = path.join('node_modules', '@github', 'copilot', 'npm-loader.js');
const STDERR_TAIL_BYTES = 4000;

function pathEntries(env, platform) {
  const raw = env.PATH ?? env.Path ?? env.path ?? '';
  return raw.split(platform === 'win32' ? ';' : ':').filter(Boolean);
}

/**
 * How to start Copilot CLI without a shell: a command and the arguments that go before the CLI's own.
 * On Windows the npm shim is a .cmd file that mangles a prompt with spaces, so run its loader with node instead.
 * COPILOT_CLI_LOADER (a path to npm-loader.js) overrides the search.
 */
function locateCopilot({ platform = process.platform, env = process.env, existsSync = fs.existsSync, nodePath = process.execPath } = {}) {
  if (platform !== 'win32') return { command: 'copilot', prefixArgs: [] };
  const candidates = [];
  if (env.COPILOT_CLI_LOADER) candidates.push(env.COPILOT_CLI_LOADER);
  // The shim sits beside node_modules in the npm global prefix, which is on PATH.
  for (const dir of pathEntries(env, platform)) {
    if (existsSync(path.join(dir, 'copilot.cmd'))) candidates.push(path.join(dir, LOADER));
  }
  if (env.APPDATA) candidates.push(path.join(env.APPDATA, 'npm', LOADER));
  if (env.npm_config_prefix) candidates.push(path.join(env.npm_config_prefix, LOADER));
  for (const candidate of candidates) {
    if (existsSync(candidate)) return { command: nodePath, prefixArgs: [candidate] };
  }
  throw new Error(
    'Could not find the Copilot CLI loader (@github/copilot/npm-loader.js). Install it with `npm install -g @github/copilot`, ' +
      'or set COPILOT_CLI_LOADER to the path of npm-loader.js.',
  );
}

/** End a process and all its children. */
function killTree(child, { platform = process.platform, spawnSync = childProcess.spawnSync, kill = process.kill.bind(process) } = {}) {
  if (!child || !child.pid) return;
  try {
    if (platform === 'win32') {
      // A plain kill leaves descendants running. taskkill may say "operation not supported" for a few; they still exit.
      spawnSync('taskkill', ['/pid', String(child.pid), '/T', '/F'], { stdio: 'ignore', windowsHide: true });
    } else {
      kill(-child.pid, 'SIGKILL'); // the child leads its own process group (detached: true)
    }
  } catch {
    try {
      child.kill('SIGKILL');
    } catch {
      // Already gone.
    }
  }
}

/**
 * Run a process to its end, reading standard output as it arrives. Resolves, and never rejects, with
 * { stdout, stderrTail, exitCode, timedOut, spawnError }. Standard error is drained and only its tail kept.
 */
function runProcess({ command, args, cwd, env, timeoutMs }, deps = {}) {
  const spawn = deps.spawn ?? childProcess.spawn;
  const platform = deps.platform ?? process.platform;
  const kill = deps.killTree ?? ((child) => killTree(child, { platform }));
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(command, args, {
        cwd,
        env,
        shell: false,
        windowsHide: true,
        detached: platform !== 'win32',
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (error) {
      resolve({ stdout: '', stderrTail: '', exitCode: undefined, timedOut: false, spawnError: error.message });
      return;
    }
    const stdout = [];
    let stderrTail = '';
    let timedOut = false;
    let settled = false;
    let spawnError;
    child.stdout.on('data', (chunk) => stdout.push(chunk));
    child.stderr.on('data', (chunk) => {
      stderrTail = (stderrTail + chunk.toString('utf8')).slice(-STDERR_TAIL_BYTES);
    });
    const timer = timeoutMs > 0
      ? setTimeout(() => {
          timedOut = true;
          kill(child);
        }, timeoutMs)
      : undefined;
    const finish = (exitCode) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ stdout: Buffer.concat(stdout).toString('utf8'), stderrTail, exitCode, timedOut, spawnError });
    };
    child.on('error', (error) => {
      spawnError = error.message;
      finish(undefined);
    });
    child.on('close', (code) => finish(code ?? undefined));
  });
}

module.exports = { locateCopilot, killTree, runProcess, pathEntries };
