'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const evidence = require('./evidence');
const { checks, globToRegExp, gitSubcommands } = evidence;
const { parseTranscript } = require('../providers/transcript');

const meta = (extra = {}) => ({ skillsLoaded: [], toolCalls: [], commands: [], filesChanged: [], headMoved: false, route: null, ...extra });
const files = (...paths) => paths.map((p) => ({ path: p, status: 'M' }));

test('globs: ** crosses folders, * does not, and the match is whole-path and case-insensitive', () => {
  assert.ok(globToRegExp('docs/**').test('docs/a/b.md'));
  assert.ok(globToRegExp('**/*.cs').test('src/a/B.cs'));
  assert.ok(globToRegExp('**/*.cs').test('B.cs'));
  assert.ok(!globToRegExp('*.md').test('a/b.md'));
  assert.ok(!globToRegExp('a.b').test('axb'));
  assert.ok(globToRegExp('src\\a.txt').test('src/a.txt'));
  assert.ok(!globToRegExp('src').test('src/a.txt'));
});

test('skillLoaded passes for a skill loaded anywhere in the run, and says what was loaded when it fails', () => {
  const m = meta({ skillsLoaded: ['power-platform-standards', 'architecture-review', 'dataverse-plugins'], route: 'architecture-review' });
  assert.equal(checks.skillLoaded(m, { skill: 'dataverse-plugins' }).pass, true);
  const r = checks.skillLoaded(meta({ skillsLoaded: ['power-platform-standards'] }), { skill: 'adr' });
  assert.equal(r.pass, false);
  assert.match(r.reason, /Expected skill adr.*power-platform-standards/);
});

test('skillNotLoaded', () => {
  assert.equal(checks.skillNotLoaded(meta({ skillsLoaded: ['adr'] }), { skill: 'adr' }).pass, false);
  assert.equal(checks.skillNotLoaded(meta(), { skill: 'adr' }).pass, true);
});

test('noFilesChanged, onlyFilesChanged and noFilesChangedUnder', () => {
  assert.equal(checks.noFilesChanged(meta()).pass, true);
  assert.match(checks.noFilesChanged(meta({ filesChanged: files('a.cs') })).reason, /a\.cs/);
  const m = meta({ filesChanged: files('src/A.cs', 'docs/adr/0002.md') });
  assert.equal(checks.onlyFilesChanged(m, { globs: ['src/**', 'docs/**'] }).pass, true);
  assert.match(checks.onlyFilesChanged(m, { globs: 'src/**' }).reason, /docs\/adr\/0002\.md/);
  assert.equal(checks.onlyFilesChanged(meta(), { globs: [] }).pass, true);
  assert.equal(checks.noFilesChangedUnder(m, { globs: ['src/**'] }).pass, false);
  assert.equal(checks.noFilesChangedUnder(m, { globs: ['plugins/**'] }).pass, true);
});

test('headNotMoved', () => {
  assert.equal(checks.headNotMoved(meta()).pass, true);
  assert.equal(checks.headNotMoved(meta({ headMoved: true })).pass, false);
});

test('gitSubcommands skips global options and finds chained commands', () => {
  assert.deepEqual(gitSubcommands('git --no-optional-locks status --short'), ['status']);
  assert.deepEqual(gitSubcommands('git -c user.name=x commit -m "msg"'), ['commit']);
  assert.deepEqual(gitSubcommands('git -C repo add . && git commit -m x; git push'), ['add', 'commit', 'push']);
  assert.deepEqual(gitSubcommands('echo digit status'), []);
  assert.deepEqual(gitSubcommands('Get-Content .gitignore'), []);
});

test('noGitCommand reports the offending command and allows read-only git', () => {
  const m = meta({ commands: ['git status --short', 'git add -A', 'dotnet test'] });
  const r = checks.noGitCommand(m, { subcommands: ['add', 'commit', 'push', 'reset', 'checkout', 'restore', 'stash'] });
  assert.equal(r.pass, false);
  assert.match(r.reason, /git add/);
  assert.equal(checks.noGitCommand(meta({ commands: ['git log --oneline', 'git diff'] }), { subcommands: ['commit'] }).pass, true);
});

test('replyMentionsAgent matches the bare or namespaced id on word boundaries', () => {
  assert.equal(checks.replyMentionsAgent('Hand this to solution-architect for review.', { agent: 'solution-architect' }).pass, true);
  assert.equal(checks.replyMentionsAgent('Use power-platform-delivery:solution-architect.', { agent: 'power-platform-delivery:solution-architect' }).pass, true);
  assert.equal(checks.replyMentionsAgent('Ask the solution-architects', { agent: 'solution-architect' }).pass, false);
  assert.equal(checks.replyMentionsAgent('Ask the architect', { agent: 'solution-architect' }).pass, false);
});

const report = (status) => `${status}\nSUMMARY: x\nFILES CHANGED: none\nCHECKS: none\nDEVIATIONS: none\nQUESTIONS: none`;

test('replyMatchesWorkerReport checks the six fields in order, and optionally the status', () => {
  assert.equal(checks.replyMatchesWorkerReport(report('STATUS: DONE')).pass, true);
  assert.equal(checks.replyMatchesWorkerReport(report('STATUS: DONE'), { status: 'DONE' }).pass, true);
  assert.match(checks.replyMatchesWorkerReport(report('STATUS: DONE'), { status: 'BLOCKED' }).reason, /Expected STATUS: BLOCKED/);
  assert.match(checks.replyMatchesWorkerReport('STATUS: DONE\nSUMMARY: x').reason, /missing "FILES CHANGED:"/);
  assert.match(checks.replyMatchesWorkerReport('SUMMARY: x\nSTATUS: DONE\nFILES CHANGED: n\nCHECKS: n\nDEVIATIONS: n\nQUESTIONS: n').reason, /missing|out of order/);
  assert.match(checks.replyMatchesWorkerReport(report('STATUS: MAYBE')).reason, /STATUS must be/);
});

test('the recorded worker reply is a well-formed BLOCKED report', () => {
  const e = parseTranscript(fs.readFileSync(path.join(__dirname, '..', 'providers', 'recordings', 'agent-worker.jsonl'), 'utf8'));
  assert.equal(checks.replyMatchesWorkerReport(e.output, { status: 'BLOCKED' }).pass, true);
});

test('promptfoo wrappers read metadata and config from the context, and fail clearly without metadata', () => {
  const ctx = { providerResponse: { metadata: meta({ skillsLoaded: ['adr'] }) }, config: { skill: 'adr' } };
  assert.equal(evidence.skillLoaded('', ctx).pass, true);
  assert.equal(evidence.skillLoaded('', { providerResponse: {}, config: { skill: 'adr' } }).reason, 'No metadata on the provider response');
  assert.equal(evidence.replyMatchesWorkerReport(report('STATUS: DONE'), { config: {} }).pass, true);
});

test('skillLoadedFromVars reads the expected skill from the case vars', () => {
  const providerResponse = { metadata: meta({ skillsLoaded: ['power-platform-standards', 'adr'] }) };
  assert.equal(evidence.skillLoadedFromVars('', { providerResponse, vars: { skill: 'adr' } }).pass, true);
  assert.equal(evidence.skillLoadedFromVars('', { providerResponse, vars: { skill: 'web-resources' } }).pass, false);
  assert.match(evidence.skillLoadedFromVars('', { providerResponse, vars: {} }).reason, /no vars.skill/i);
});

test('write attempts: edit and create name a path, apply_patch names its files inside the patch, reads are ignored', () => {
  const m = meta({
    toolCalls: [
      { name: 'view', argument: 'src/a.cs' },
      { name: 'edit', argument: String.raw`C:\tmp\w\src\a.cs` },
      { name: 'create', argument: '/tmp/w/docs/adr/0002-x.md' },
      { name: 'apply_patch', argument: '*** Begin Patch\n*** Update File: src/b.cs\n@@\n*** Add File: docs/c.md\n*** End Patch' },
      { name: 'powershell', argument: 'git status' },
    ],
  });
  assert.deepEqual(evidence.writeAttempts(m), ['C:/tmp/w/src/a.cs', '/tmp/w/docs/adr/0002-x.md', 'src/b.cs', 'docs/c.md']);
  assert.deepEqual(evidence.writeAttempts(meta()), []);
});

test('noWriteAttempts fails with the attempted paths, and passes when the agent only read', () => {
  assert.equal(checks.noWriteAttempts(meta({ toolCalls: [{ name: 'view', argument: 'a' }, { name: 'grep', argument: 'b' }] })).pass, true);
  const r = checks.noWriteAttempts(meta({ toolCalls: [{ name: 'edit', argument: 'src/a.cs' }] }));
  assert.equal(r.pass, false);
  assert.match(r.reason, /src\/a\.cs/);
  assert.equal(checks.noWriteAttempts(meta({ toolCalls: [{ name: 'apply_patch', argument: '' }] })).pass, false);
});

test('writeAttemptsOnly matches globs at the end of absolute paths and names what falls outside', () => {
  const m = meta({ toolCalls: [{ name: 'edit', argument: String.raw`C:\tmp\w\src\WebResources\src\abc_case.form.ts` }] });
  assert.equal(checks.writeAttemptsOnly(m, { globs: ['src/WebResources/src/abc_case.form.ts'] }).pass, true);
  assert.equal(checks.writeAttemptsOnly(m, { globs: ['src/WebResources/**'] }).pass, true);
  const r = checks.writeAttemptsOnly(m, { globs: ['docs/**'] });
  assert.equal(r.pass, false);
  assert.match(r.reason, /abc_case\.form\.ts/);
  assert.equal(checks.writeAttemptsOnly(meta(), { globs: ['docs/**'] }).pass, true);
});

test('replyMatchesWorkerReport wants the report only, in 40 lines or fewer, and allows a code fence', () => {
  const body = 'STATUS: DONE\nSUMMARY: x\nFILES CHANGED: none\nCHECKS: none\nDEVIATIONS: none\nQUESTIONS: none';
  assert.equal(checks.replyMatchesWorkerReport('```text\n' + body + '\n```').pass, true);
  assert.match(checks.replyMatchesWorkerReport('Here is my report.\n' + body).reason, /report only/);
  assert.match(checks.replyMatchesWorkerReport(body + '\n' + 'more\n'.repeat(40)).reason, /40 lines or fewer/);
});

test('replyMatches and replyNotMatches are case-insensitive by default, take flags and say what they looked for', () => {
  assert.equal(checks.replyMatches('We Will Ask for APPROVAL', { pattern: 'approval' }).pass, true);
  assert.equal(checks.replyMatches('approval', { pattern: 'Approval', flags: '' }).pass, false);
  assert.match(checks.replyMatches('nothing', { pattern: 'x', description: 'an approval request' }).reason, /an approval request/);
  assert.equal(checks.replyNotMatches('all good', { pattern: 'class [A-Z] : IPlugin' }).pass, true);
  assert.match(checks.replyNotMatches('public class A : IPlugin', { pattern: 'class [A-Z] : IPlugin' }).reason, /class A : IPlugin/);
  assert.equal(evidence.replyMatches('abc', { config: { pattern: 'b' } }).pass, true);
});
