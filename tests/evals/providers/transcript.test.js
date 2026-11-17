'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { parseTranscript, parseUsage, parseLines, routeOf, isShellTool } = require('./transcript');

const recording = (name, ext = 'jsonl') => fs.readFileSync(path.join(__dirname, 'recordings', `${name}.${ext}`), 'utf8');
const line = (type, data, extra = {}) => JSON.stringify({ type, data, ...extra });

test('routing recording: standards skill, glob, reply, clean finish', () => {
  const e = parseTranscript(recording('routing-no-agent'));
  assert.deepEqual(e.skillsLoaded, ['power-platform-standards']);
  assert.equal(e.route, null);
  assert.deepEqual(e.toolCalls.map((c) => c.name), ['skill', 'glob']);
  assert.match(e.output, /Inspection/);
  assert.equal(e.exitCode, 0);
  assert.equal(e.finished, true);
  assert.equal(e.copilotVersion, '1.0.112');
});

test('developer recording: shell commands are a subset of tool calls', () => {
  const e = parseTranscript(recording('agent-developer'));
  assert.deepEqual(e.commands, ['git --no-optional-locks status --short']);
  assert.equal(e.toolCalls.length, 5);
  assert.deepEqual(e.skillsLoaded, ['power-platform-standards']);
});

test('worker recording: fixed report is the final reply and no skill is loaded', () => {
  const e = parseTranscript(recording('agent-worker'));
  assert.match(e.output, /^STATUS: BLOCKED/);
  assert.deepEqual(e.skillsLoaded, []);
  assert.deepEqual(e.toolCalls.map((c) => c.name), ['view', 'edit']);
});

test('unknown event types and unknown tools are tolerated', () => {
  const text = [
    line('something.new', { x: 1 }),
    line('tool.execution_start', { toolName: 'brand_new_tool', arguments: { weird: true } }),
    line('tool.execution_start', { toolName: 'skill', arguments: { skill: 'adr' } }),
    line('result', undefined, { exitCode: 0 }),
  ].join('\n');
  const e = parseTranscript(text);
  assert.deepEqual(e.skillsLoaded, ['adr']);
  assert.equal(e.route, 'adr');
  assert.deepEqual(e.toolCalls[0], { name: 'brand_new_tool', argument: '' });
  assert.equal(e.finished, true);
});

test('empty, null and truncated transcripts give empty evidence, not an exception', () => {
  for (const text of ['', null, undefined, '\n\n']) {
    const e = parseTranscript(text);
    assert.deepEqual(e.skillsLoaded, []);
    assert.equal(e.finished, false);
    assert.equal(e.output, '');
  }
  const truncated = `${line('tool.execution_start', { toolName: 'skill', arguments: { skill: 'adr' } })}\n{"type":"tool.execution_st`;
  const e = parseTranscript(truncated);
  assert.deepEqual(e.skillsLoaded, ['adr']);
  assert.equal(e.finished, false);
});

test('parseLines skips non-object JSON', () => {
  assert.equal(parseLines('1\n"text"\nnull\n{"type":"a"}').length, 1);
});

test('the last non-empty assistant message is the reply', () => {
  const text = [
    line('assistant.message', { content: 'first' }),
    line('assistant.message', { content: '', toolRequests: [{}] }),
    line('assistant.message', { content: 'final' }),
    line('assistant.message', { content: '   ' }),
  ].join('\n');
  assert.equal(parseTranscript(text).output, 'final');
});

test('a quota failure is reported as such', () => {
  const text = [line('session.error', { errorType: 'quota', message: 'HTTP 402' }), line('result', undefined, { exitCode: 1 })].join('\n');
  const e = parseTranscript(text);
  assert.equal(e.quotaExceeded, true);
  assert.deepEqual(e.errors, [{ type: 'quota', message: 'HTTP 402' }]);
  assert.equal(e.exitCode, 1);
});

test('subagents come from subagent.started, whichever field names the agent', () => {
  const text = [
    line('subagent.started', { agentName: 'power-platform-delivery:developer-worker' }),
    line('subagent.started', { name: 'search' }),
    line('subagent.started', {}),
  ].join('\n');
  assert.deepEqual(parseTranscript(text).subagents, ['power-platform-delivery:developer-worker', 'search']);
});

test('shell tools are recognised under the names seen on Windows and expected elsewhere', () => {
  for (const name of ['powershell', 'bash', 'shell', 'Bash']) assert.equal(isShellTool(name), true, name);
  for (const name of ['view', 'edit', 'skill', 'glob']) assert.equal(isShellTool(name), false, name);
});

test('routeOf skips the shared standards skill and returns the first other skill', () => {
  assert.equal(routeOf(['power-platform-standards', 'architecture-review', 'dataverse-plugins']), 'architecture-review');
  assert.equal(routeOf(['power-platform-standards']), undefined);
  assert.equal(routeOf([]), undefined);
  assert.equal(routeOf(undefined), undefined);
});

test('usage file: credits, per-agent credits, premium requests and tokens', () => {
  const u = parseUsage(recording('routing-no-agent', 'usage.json'));
  assert.ok(Math.abs(u.credits - 4.73849) < 1e-9);
  assert.deepEqual(Object.keys(u.byAgent), ['main']);
  assert.equal(u.premiumRequests, 1);
  assert.deepEqual(u.tokenUsage, { prompt: 66909, completion: 861, total: 67770 });
});

test('usage file: missing or corrupt input is undefined, and a zeroed file is zero credits', () => {
  assert.equal(parseUsage(''), undefined);
  assert.equal(parseUsage('{not json'), undefined);
  assert.equal(parseUsage('null'), undefined);
  assert.equal(parseUsage('{}').credits, 0);
});
