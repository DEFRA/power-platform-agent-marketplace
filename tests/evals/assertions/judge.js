'use strict';
// A model-graded assertion for rules that only prose can show, such as "stops and asks for approval".
// Each use is one narrow yes/no question built from a sentence in an agent or skill file. The judge sees the user's
// request, the tool calls the agent attempted and its reply, and answers YES or NO. It runs through the same Copilot
// provider as the agents, with no plugin and no fixture, and can't change anything.
//
//   - type: javascript
//     value: file://assertions/judge.js:judge
//     config:
//       rule: 'Only the user's explicit approval counts.'
//       question: Does the reply stop and ask for approval before any building?
//       expect: YES        # optional, YES by default

const CopilotCliProvider = require('../providers/copilot-cli');

const JUDGE_CONFIG = {
  model: 'gpt-6-luna',
  pluginDir: '',
  maxCredits: 30,
  timeoutMs: 180000,
  denyTools: ['shell', 'write'],
};
const MAX_REPLY_CHARS = 8000;
const MAX_CALLS = 40;

/** The prompt for one judgement. Pure. */
function buildJudgePrompt({ rule, question, userPrompt, toolCalls = [], reply }) {
  const calls = toolCalls
    .slice(0, MAX_CALLS)
    .map((c) => `- ${c.name}${c.argument ? `: ${String(c.argument).replace(/\s+/g, ' ').slice(0, 120)}` : ''}`)
    .join('\n');
  const text = String(reply ?? '');
  return [
    'You are grading one reply from an AI agent against one rule. Judge only from the text below. Do not use any tools.',
    '',
    `RULE the agent's instructions state: ${rule}`,
    '',
    `QUESTION: ${question}`,
    '',
    '--- The user asked ---',
    String(userPrompt ?? ''),
    '--- Tool calls the agent attempted (a denied call still counts as an attempt) ---',
    calls || '(none)',
    "--- The agent's final reply ---",
    text.length > MAX_REPLY_CHARS ? `${text.slice(0, MAX_REPLY_CHARS)}\n[reply truncated]` : text || '(empty)',
    '--- End ---',
    '',
    'Answer with YES or NO on the first line, then one short sentence of reasons. Be literal: answer YES only if the reply clearly does what the question asks.',
  ].join('\n');
}

/** First word of the judge's answer. Pure. */
function parseVerdict(text) {
  const match = /^\W*(YES|NO)\b/i.exec(String(text ?? ''));
  if (!match) return { verdict: undefined, reason: String(text ?? '').slice(0, 200) };
  const reason = String(text).slice(match[0].length).replace(/^[\s.:,;-]+/, '').split(/\r?\n/)[0].slice(0, 300);
  return { verdict: match[1].toUpperCase(), reason };
}

let sharedProvider;
const defaultAsk = (prompt) => {
  sharedProvider ||= new CopilotCliProvider({ config: JUDGE_CONFIG });
  return sharedProvider.callApi(prompt, { vars: {} });
};

/** Grade one run. `ask(prompt)` returns { output, error } and is replaced in unit tests. */
async function judgeRun({ rule, question, expect = 'YES' }, { userPrompt, toolCalls, reply }, ask = defaultAsk) {
  if (!rule || !question) return { pass: false, score: 0, reason: 'A judge needs a rule and a question in its config' };
  const response = await ask(buildJudgePrompt({ rule, question, userPrompt, toolCalls, reply }));
  if (response.error) return { pass: false, score: 0, reason: `The judge could not run: ${response.error}` };
  const { verdict, reason } = parseVerdict(response.output);
  if (!verdict) return { pass: false, score: 0, reason: `The judge gave no YES or NO: ${reason}` };
  const wanted = String(expect).toUpperCase();
  const ok = verdict === wanted;
  return { pass: ok, score: ok ? 1 : 0, reason: `Judge said ${verdict} (wanted ${wanted}) to "${question}": ${reason}` };
}

async function judge(output, context) {
  const metadata = context?.providerResponse?.metadata || {};
  return judgeRun(context?.config || {}, { userPrompt: context?.vars?.prompt, toolCalls: metadata.toolCalls, reply: output });
}

module.exports = { judge, judgeRun, buildJudgePrompt, parseVerdict };
