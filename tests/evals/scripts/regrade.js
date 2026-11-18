#!/usr/bin/env node
'use strict';
// Grades the stored replies of an earlier run again, without running any agent.
//
//   node scripts/regrade.js [results/behaviour.json] [--suite behaviour] [--filter B-QE] [--grader <provider id>]
//
// Use it after changing an assertion or a rubric: the agents' replies and evidence are read from the results
// file, the case's current assertions are run over them, and a summary is printed. `llm-rubric` assertions call the grader
// (a few tenths of a credit each), everything else is free. `--grader` replaces the grader provider in the config,
// as it does for `promptfoo eval`. Nothing is written.

const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const { assertions } = require('promptfoo');

const root = path.join(__dirname, '..');
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const at = args.indexOf(name);
  return at === -1 ? fallback : args[at + 1];
};
const suite = option('--suite', 'behaviour');
const graderOverride = option('--grader', '');
const filter = option('--filter', '');
const file = args.find((a, i) => !a.startsWith('--') && !['--suite', '--filter', '--grader'].includes(args[i - 1])) || path.join('results', `${suite}.json`);
const CONCURRENCY = 6;

const config = yaml.load(fs.readFileSync(path.join(root, `promptfooconfig.${suite}.yaml`), 'utf8'));
// A case is found by its id (the first word of its description, such as B-QE-3), because descriptions get edited.
const caseId = (description) => String(description).trim().split(/\s+/)[0];
const cases = new Map();
for (const ref of [].concat(config.tests)) {
  for (const test of yaml.load(fs.readFileSync(path.join(root, String(ref).replace(/^file:\/\//, '')), 'utf8'))) {
    cases.set(caseId(test.description), test);
  }
}
const defaultAsserts = (config.defaultTest && config.defaultTest.assert) || [];
// Provider files in the config are relative to this folder, as they are for `promptfoo eval`.
process.chdir(root);
const grading = { ...((config.defaultTest && config.defaultTest.options) || {}) };
if (graderOverride) grading.provider = graderOverride;

const functionFor = (value) => {
  const [, modulePath, name] = /^file:\/\/(.+?):(\w+)$/.exec(value) || [];
  if (!modulePath) throw new Error(`Unsupported assertion value: ${value}`);
  const fn = require(path.join(root, modulePath))[name];
  if (typeof fn !== 'function') throw new Error(`${value} is not a function`);
  return fn;
};

async function grade(result) {
  const test = cases.get(caseId(result.testCase.description));
  if (!test) return { id: result.testCase.description.split(' ')[0], failures: ['The case is no longer in the case files'] };
  const response = result.response || {};
  const context = { providerResponse: response, vars: { ...result.vars, ...test.vars }, config: {} };
  const failures = [];
  if (!response.output && !response.metadata) failures.push(`No reply was stored${result.error ? `: ${result.error}` : ''}`);
  else {
    for (const assertion of [...defaultAsserts, ...(test.assert || [])]) {
      const outcome = assertion.type === 'llm-rubric'
        ? await assertions.matchesLlmRubric(assertion.value, response.output, grading, context.vars, assertion)
        : await functionFor(assertion.value)(response.output, { ...context, config: assertion.config || {} });
      if (!outcome.pass) failures.push(outcome.reason);
    }
  }
  return { id: String(test.description).split(' ')[0], failures, credits: response.metadata?.credits?.total || 0 };
}

async function main() {
  const stored = JSON.parse(fs.readFileSync(path.resolve(root, file), 'utf8')).results.results.filter((r) => String(r.testCase.description).includes(filter));
  const graded = new Array(stored.length);
  let next = 0;
  await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
    while (next < stored.length) {
      const at = next++;
      graded[at] = await grade(stored[at]);
    }
  }));
  const byCase = {};
  for (const g of graded) {
    const entry = (byCase[g.id] ||= { pass: 0, runs: 0, failures: [] });
    entry.runs++;
    if (!g.failures.length) entry.pass++;
    entry.failures.push(...g.failures);
  }
  let passed = 0;
  for (const [id, entry] of Object.entries(byCase).sort()) {
    passed += entry.pass;
    console.log(`${id} ${entry.pass}/${entry.runs}`);
    const counts = new Map();
    for (const f of entry.failures) counts.set(f.slice(0, 330), (counts.get(f.slice(0, 330)) || 0) + 1);
    for (const [text, n] of counts) console.log(`    x${n} ${text}`);
  }
  console.log(`${passed} of ${graded.length} runs passed every assertion`);
  process.exit(passed === graded.length ? 0 : 100);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(2);
});
