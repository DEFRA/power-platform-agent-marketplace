'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { judgeRun, buildJudgePrompt, parseVerdict } = require('./judge');

const config = { rule: 'Only explicit approval counts.', question: 'Does the reply ask for approval?' };
const run = { userPrompt: 'Add a plug-in', toolCalls: [{ name: 'skill', argument: 'adr' }], reply: 'Shall I go ahead?' };
const asking = (output, error) => async () => ({ output, error });

test('the judge prompt carries the rule, the question, the request, the attempted calls and the reply', () => {
  const prompt = buildJudgePrompt({ ...config, ...run });
  for (const part of ['Only explicit approval counts.', 'Does the reply ask for approval?', 'Add a plug-in', '- skill: adr', 'Shall I go ahead?', 'Do not use any tools']) {
    assert.ok(prompt.includes(part), part);
  }
  assert.match(buildJudgePrompt({ ...config, userPrompt: 'x', reply: '' }), /\(none\)[\s\S]*\(empty\)/);
});

test('a long reply is truncated and says so', () => {
  const prompt = buildJudgePrompt({ ...config, ...run, reply: 'x'.repeat(20000) });
  assert.ok(prompt.length < 12000);
  assert.match(prompt, /\[reply truncated\]/);
});

test('parseVerdict reads YES or NO from the start of the answer, in any case, and keeps the first line of reasons', () => {
  assert.deepEqual(parseVerdict('YES. It asks first.\nMore.'), { verdict: 'YES', reason: 'It asks first.' });
  assert.equal(parseVerdict('no - it just builds').verdict, 'NO');
  assert.equal(parseVerdict('**YES**').verdict, 'YES');
  assert.equal(parseVerdict('Maybe').verdict, undefined);
  assert.equal(parseVerdict('Nobody knows').verdict, undefined, 'NO must be a whole word');
  assert.equal(parseVerdict(undefined).verdict, undefined);
});

test('judgeRun passes when the verdict is the one expected, and fails with the judge\'s reason when it isn\'t', async () => {
  assert.equal((await judgeRun(config, run, asking('YES. It asks.'))).pass, true);
  const no = await judgeRun(config, run, asking('NO. It builds.'));
  assert.equal(no.pass, false);
  assert.match(no.reason, /Judge said NO \(wanted YES\).*It builds/);
  assert.equal((await judgeRun({ ...config, expect: 'no' }, run, asking('NO. It builds.'))).pass, true);
});

test('judgeRun fails clearly when the judge errors, gives no verdict, or the config is incomplete', async () => {
  assert.match((await judgeRun(config, run, asking('', 'quota'))).reason, /could not run: quota/);
  assert.match((await judgeRun(config, run, asking('Hard to say'))).reason, /no YES or NO: Hard to say/);
  assert.match((await judgeRun({ question: 'q' }, run, asking('YES'))).reason, /needs a rule and a question/);
});
