'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { rowsFrom, summarise, evaluate, baselineFrom, skillsAllFailed } = require('./thresholds');

const row = (skill, status, extra = {}) => ({
  vars: { skill },
  success: status === 'pass',
  error: status === 'pass' ? undefined : 'some reason',
  failureReason: status === 'pass' ? 0 : status === 'fail' ? 1 : 2,
  response: { ...(status === 'error' ? { error: 'Timed out' } : {}), metadata: { credits: { total: 1 }, model: 'gpt-6-luna', copilotVersion: '1.0.112', route: null } },
  ...extra,
});
const file = (...rows) => ({ results: { results: rows } });

test('rows are classified as pass, fail or provider error, and credits are summed', () => {
  const s = summarise(rowsFrom(file(row('adr', 'pass'), row('adr', 'fail'), row('web-resources', 'error'))));
  assert.equal(s.passed, 1);
  assert.equal(s.failed, 1);
  assert.equal(s.errors, 1);
  assert.equal(s.passRate, 0.5, 'errors are not counted in the pass rate');
  assert.equal(s.credits, 3);
  assert.equal(s.model, 'gpt-6-luna');
  assert.deepEqual(s.bySkill.adr, { pass: 1, fail: 1, error: 0 });
});

test('a file that is not promptfoo output is rejected', () => {
  assert.throws(() => rowsFrom({}), /Not a promptfoo results file/);
});

test('skillsAllFailed names skills where no run passed', () => {
  assert.deepEqual(skillsAllFailed({ a: { pass: 0, fail: 2, error: 0 }, b: { pass: 1, fail: 1, error: 0 }, c: { pass: 0, fail: 0, error: 2 } }), ['a']);
});

const baseline = { passRate: 0.9 };

test('within the margin of the baseline is OK', () => {
  const rows = [...Array(17)].map(() => row('a', 'pass')).concat([row('b', 'pass'), row('b', 'fail'), row('c', 'pass')]);
  const result = evaluate(summarise(rowsFrom(file(...rows))), baseline, 0.1);
  assert.equal(result.exitCode, 0);
  assert.match(result.messages[0], /^OK/);
});

test('a pass rate below baseline minus margin fails', () => {
  const rows = [row('a', 'pass'), row('a', 'fail'), row('b', 'pass'), row('b', 'fail')];
  const result = evaluate(summarise(rowsFrom(file(...rows))), baseline, 0.1);
  assert.equal(result.exitCode, 1);
  assert.match(result.messages.join('\n'), /below the baseline 90\.0% minus a margin of 10\.0%/);
});

test('both positive cases failing for one skill fails even when the overall rate is fine', () => {
  const rows = [...Array(30)].map(() => row('a', 'pass')).concat([row('b', 'fail'), row('b', 'fail')]);
  const result = evaluate(summarise(rowsFrom(file(...rows))), baseline, 0.1);
  assert.equal(result.exitCode, 1);
  assert.match(result.messages.join('\n'), /every run failed for b/);
});

test('provider errors make the run incomplete (exit 2), which outranks a threshold failure', () => {
  const rows = [row('a', 'error'), row('b', 'fail'), row('b', 'fail')];
  const result = evaluate(summarise(rowsFrom(file(...rows))), baseline, 0.1);
  assert.equal(result.exitCode, 2);
  assert.match(result.messages[0], /INCOMPLETE: 1 of 3/);
});

test('with no baseline it says so and does not fail on rate', () => {
  const result = evaluate(summarise(rowsFrom(file(row('a', 'pass')))), undefined);
  assert.equal(result.exitCode, 0);
  assert.match(result.messages.join(' '), /No baseline/);
});

test('a baseline records rate, model, CLI version, credits and the skills that failed', () => {
  const s = summarise(rowsFrom(file(row('a', 'pass'), row('b', 'fail'), row('b', 'pass'))));
  const b = baselineFrom(s, new Date('2026-11-17T10:00:00Z'));
  assert.deepEqual(b, {
    recordedAt: '2026-11-17',
    model: 'gpt-6-luna',
    copilotVersion: '1.0.112',
    runs: 3,
    passed: 2,
    failed: 1,
    passRate: 0.6667,
    credits: 3,
    skillsWithFailures: { b: { pass: 1, fail: 1, error: 0 } },
  });
});
