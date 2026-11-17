'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const Provider = require('./copilot-cli');
const { resolveConfig, buildArgs } = Provider;

const recording = (name) => fs.readFileSync(path.join(__dirname, 'recordings', `${name}.jsonl`), 'utf8');
const usageRecording = (name) => fs.readFileSync(path.join(__dirname, 'recordings', `${name}.usage.json`), 'utf8');
const base = { model: 'gpt-6-luna' };
const valueAfter = (args, flag) => args[args.indexOf(flag) + 1];

test('resolveConfig requires a model and a credit cap of at least 30', () => {
  assert.throws(() => resolveConfig({}), /model is required/);
  assert.throws(() => resolveConfig({ ...base, maxCredits: 5 }), /at least 30/);
  assert.throws(() => resolveConfig({ ...base, maxCredits: 'lots' }), /at least 30/);
  assert.equal(resolveConfig(base).maxCredits, 30);
});

test('vars override config for known keys only', () => {
  const c = resolveConfig({ ...base, agent: 'a' }, { agent: 'b', model: 'other', prompt: 'ignored', unknown: 1, overlay: '' });
  assert.equal(c.agent, 'b');
  assert.equal(c.model, 'other');
  assert.equal(c.prompt, undefined);
  assert.equal(c.unknown, undefined);
  assert.equal(c.overlay, undefined);
});

test('buildArgs: fixed flags, model, plugin, credit cap and usage file', () => {
  const args = buildArgs(resolveConfig(base), 'hello', { pluginDir: '/p', usageFile: '/u.json' });
  assert.equal(valueAfter(args, '-p'), 'hello');
  assert.equal(valueAfter(args, '--output-format'), 'json');
  assert.equal(valueAfter(args, '--plugin-dir'), '/p');
  assert.equal(valueAfter(args, '--model'), 'gpt-6-luna');
  assert.equal(valueAfter(args, '--max-ai-credits'), '30');
  assert.equal(valueAfter(args, '--usage-output-file'), '/u.json');
  for (const flag of ['--no-ask-user', '--no-custom-instructions']) assert.ok(args.includes(flag), flag);
  for (const flag of ['--agent', '--autopilot', '--allow-all-tools', '--allow-all-paths', '--stop-when']) assert.ok(!args.includes(flag), `${flag} absent`);
});

test('buildArgs keeps a prompt with quotes, newlines and a leading dash as one argument', () => {
  const prompt = '--not-a-flag "quoted" it\'s\nsecond line\r\n`tick` $var %PATH%';
  const args = buildArgs(resolveConfig(base), prompt, { pluginDir: '/p', usageFile: '/u' });
  assert.equal(args[args.indexOf('-p') + 1], prompt);
  assert.equal(args.filter((a) => a === prompt).length, 1);
});

test('buildArgs: agent, autopilot limit and permission rules, one argument per rule', () => {
  const config = resolveConfig({ ...base, agent: 'power-platform-delivery:developer', autopilot: 3, denyTools: ['shell', 'write'], allowTools: 'view' });
  const args = buildArgs(config, 'p', { pluginDir: '/p', usageFile: '/u' });
  assert.equal(valueAfter(args, '--agent'), 'power-platform-delivery:developer');
  assert.ok(args.includes('--autopilot'));
  assert.equal(valueAfter(args, '--max-autopilot-continues'), '3');
  assert.ok(args.includes('--deny-tool=shell') && args.includes('--deny-tool=write'));
  assert.ok(args.includes('--allow-tool=view'));
  assert.ok(!buildArgs(resolveConfig({ ...base, autopilot: true }), 'p', { pluginDir: '/p', usageFile: '/u' }).includes('--max-autopilot-continues'));
});

// A provider with every collaborator faked. `run` receives the spawn request and may write the usage file.
function fakeProvider({ run, config = {}, env = { GH_TOKEN: 'x' }, versionOutput, locate, evidence } = {}) {
  const cleaned = [];
  const provider = new Provider({
    config: { ...base, ...config },
    deps: {
      env,
      platform: 'linux',
      locate: locate ?? (() => ({ command: 'copilot', prefixArgs: [] })),
      version: () => versionOutput ?? { status: 0, stdout: 'GitHub Copilot CLI 1.0.112.\n', stderr: '' },
      prepare: () => {
        const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ppd-eval-fake-'));
        return { root, dir: root, copilotHome: path.join(root, 'h'), baseline: 'abc', usageFile: path.join(root, 'usage.json') };
      },
      gitEvidence: () => evidence ?? { filesChanged: [], headMoved: false, diff: '' },
      cleanup: (root) => {
        cleaned.push(root);
        fs.rmSync(root, { recursive: true, force: true });
      },
      run,
    },
  });
  return { provider, cleaned };
}

const finishedRun = (name, overrides = {}) => async (request) => {
  fs.writeFileSync(request.args[request.args.indexOf('--usage-output-file') + 1], usageRecording(name));
  return { stdout: recording(name), stderrTail: '', exitCode: 0, timedOut: false, ...overrides };
};

test('a successful run returns the reply, evidence, credits and token usage', async () => {
  let request;
  const { provider, cleaned } = fakeProvider({ run: async (r) => ((request = r), finishedRun('routing-no-agent')(r)) });
  const res = await provider.callApi('how do I add a column?', { vars: {} });
  assert.equal(res.error, undefined);
  assert.match(res.output, /Inspection/);
  assert.deepEqual(res.metadata.skillsLoaded, ['power-platform-standards']);
  assert.equal(res.metadata.route, null);
  assert.equal(res.metadata.headMoved, false);
  assert.equal(res.metadata.copilotVersion, '1.0.112');
  assert.equal(res.metadata.model, 'gpt-6-luna');
  assert.ok(Math.abs(res.metadata.credits.total - 4.73849) < 1e-9);
  assert.equal(res.tokenUsage.total, 67770);
  assert.equal(request.env.COPILOT_HOME.endsWith('h'), true);
  assert.equal(cleaned.length, 1, 'the temporary folder is removed');
});

test('a time-out is a provider error and the folder is still removed', async () => {
  const { provider, cleaned } = fakeProvider({ run: async () => ({ stdout: '', stderrTail: '', exitCode: undefined, timedOut: true }), config: { timeoutMs: 1000 } });
  const res = await provider.callApi('p', { vars: {} });
  assert.match(res.error, /Timed out after 1000 ms/);
  assert.equal(cleaned.length, 1);
});

test('a non-zero exit is a provider error that carries the session error', async () => {
  const stdout = [JSON.stringify({ type: 'session.error', data: { errorType: 'model_failure', message: 'boom' } }), JSON.stringify({ type: 'result', exitCode: 1 })].join('\n');
  const { provider } = fakeProvider({ run: async () => ({ stdout, stderrTail: '', exitCode: 1, timedOut: false }) });
  const res = await provider.callApi('p', { vars: {} });
  assert.match(res.error, /exited with code 1.*model_failure: boom/);
});

test('a quota failure is a provider error', async () => {
  const stdout = [JSON.stringify({ type: 'session.error', data: { errorType: 'quota', message: '402' } }), JSON.stringify({ type: 'result', exitCode: 1 })].join('\n');
  const { provider } = fakeProvider({ run: async () => ({ stdout, stderrTail: '', exitCode: 1, timedOut: false }) });
  assert.match((await provider.callApi('p', { vars: {} })).error, /quota exhausted/);
});

test('exit 0 without a result event, and a spawn failure, are provider errors', async () => {
  const noResult = fakeProvider({ run: async () => ({ stdout: '', stderrTail: 'oops', exitCode: 0, timedOut: false }) });
  assert.match((await noResult.provider.callApi('p', { vars: {} })).error, /without a result event.*oops/);
  const spawnFail = fakeProvider({ run: async () => ({ stdout: '', stderrTail: '', timedOut: false, spawnError: 'ENOENT' }) });
  assert.match((await spawnFail.provider.callApi('p', { vars: {} })).error, /Could not start Copilot CLI: ENOENT/);
});

test('a run with no usage file still returns evidence', async () => {
  const { provider } = fakeProvider({ run: async () => ({ stdout: recording('agent-worker'), stderrTail: '', exitCode: 0, timedOut: false }) });
  const res = await provider.callApi('p', { vars: {} });
  assert.equal(res.error, undefined);
  assert.equal(res.metadata.credits, undefined);
  assert.equal(res.tokenUsage, undefined);
});

test('fails fast with a clear message: no token, CLI not installed, CLI does not run, bad config', async () => {
  let ran = false;
  const run = async () => ((ran = true), {});
  assert.match((await fakeProvider({ run, env: {} }).provider.callApi('p', { vars: {} })).error, /Not authenticated.*COPILOT_GITHUB_TOKEN/);
  assert.match(
    (await fakeProvider({ run, locate: () => { throw new Error('Could not find the Copilot CLI loader'); } }).provider.callApi('p', { vars: {} })).error,
    /Could not find the Copilot CLI loader/,
  );
  assert.match((await fakeProvider({ run, versionOutput: { status: 1, stdout: '', stderr: 'bad' } }).provider.callApi('p', { vars: {} })).error, /did not run: bad/);
  assert.match((await fakeProvider({ run, config: { maxCredits: 1 } }).provider.callApi('p', { vars: {} })).error, /at least 30/);
  assert.equal(ran, false, 'no process starts when preflight fails');
});

test('a token is never written into the error text or the arguments', async () => {
  const secret = 'ghp_secretvalue123';
  let request;
  const { provider } = fakeProvider({ env: { COPILOT_GITHUB_TOKEN: secret }, run: async (r) => ((request = r), { stdout: '', stderrTail: '', exitCode: 1, timedOut: false }) });
  const res = await provider.callApi('p', { vars: {} });
  assert.ok(!JSON.stringify(res).includes(secret));
  assert.ok(!request.args.join(' ').includes(secret));
});

test('per-test vars reach the arguments, and replay mode needs no CLI', async () => {
  let request;
  const { provider } = fakeProvider({ run: async (r) => ((request = r), finishedRun('agent-worker')(r)) });
  await provider.callApi('p', { vars: { agent: 'power-platform-delivery:developer-worker', denyTools: ['shell'] } });
  assert.equal(valueAfter(request.args, '--agent'), 'power-platform-delivery:developer-worker');
  assert.ok(request.args.includes('--deny-tool=shell'));

  const replay = new Provider({ config: { replay: 'recordings/routing-no-agent.jsonl' } });
  const res = await replay.callApi('p', { vars: {} });
  assert.deepEqual(res.metadata.skillsLoaded, ['power-platform-standards']);
});
