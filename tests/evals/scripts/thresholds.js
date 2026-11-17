#!/usr/bin/env node
'use strict';
// Applies the routing thresholds (docs/testing-plan.md section 7.5) to a promptfoo JSON results file, because
// promptfoo has no pass-rate threshold flag. No dependencies.
//
//   node scripts/thresholds.js <results.json> [--baseline baselines/routing.json] [--margin 0.1] [--write-baseline]
//
// Exit codes: 0 within thresholds, 1 below a threshold, 2 the run has provider errors or can't be read.
// A provider error (time-out, credit cap, quota, authentication) is not a failed case, so it is counted apart
// and the run is reported as incomplete.

const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_BASELINE = path.join(__dirname, '..', 'baselines', 'routing.json');
const DEFAULT_MARGIN = 0.1;

/** One row per executed case, from promptfoo's `results.results` array. */
function rowsFrom(json) {
  const rows = json?.results?.results;
  if (!Array.isArray(rows)) throw new Error('Not a promptfoo results file: results.results is missing');
  return rows.map((r) => ({
    skill: r.vars?.skill ?? r.testCase?.vars?.skill ?? r.description ?? 'unknown',
    // promptfoo's failureReason is 1 for a failed assertion and 2 for an error, and `error` is also set for failures.
    status: r.response?.error || r.failureReason === 2 ? 'error' : r.success ? 'pass' : 'fail',
    credits: r.response?.metadata?.credits?.total ?? 0,
    route: r.response?.metadata?.route ?? null,
    model: r.response?.metadata?.model,
    copilotVersion: r.response?.metadata?.copilotVersion,
  }));
}

function summarise(rows) {
  const bySkill = {};
  for (const row of rows) {
    const s = (bySkill[row.skill] ??= { pass: 0, fail: 0, error: 0 });
    s[row.status] += 1;
  }
  const count = (status) => rows.filter((r) => r.status === status).length;
  const passed = count('pass');
  const failed = count('fail');
  return {
    runs: rows.length,
    passed,
    failed,
    errors: count('error'),
    passRate: passed + failed ? passed / (passed + failed) : 0,
    credits: rows.reduce((sum, r) => sum + r.credits, 0),
    bySkill,
    model: rows.find((r) => r.model)?.model,
    copilotVersion: rows.find((r) => r.copilotVersion)?.copilotVersion,
  };
}

/** Skills where every counted run failed. With two prompts per skill this is "both positive cases fail". */
const skillsAllFailed = (bySkill) => Object.entries(bySkill).filter(([, s]) => s.fail > 0 && s.pass === 0).map(([name]) => name);

/** Compare a summary with a baseline. Returns { exitCode, messages }. */
function evaluate(summary, baseline, margin = DEFAULT_MARGIN) {
  const messages = [];
  let exitCode = 0;
  if (summary.errors > 0) {
    messages.push(`INCOMPLETE: ${summary.errors} of ${summary.runs} runs ended in a provider error, so they are not counted as failures. Rerun them.`);
    exitCode = 2;
  }
  const dead = skillsAllFailed(summary.bySkill);
  if (dead.length) {
    messages.push(`FAIL: every run failed for ${dead.join(', ')}.`);
    exitCode = Math.max(exitCode, 1);
  }
  if (baseline) {
    const floor = baseline.passRate - margin;
    if (summary.passRate < floor) {
      messages.push(`FAIL: pass rate ${pct(summary.passRate)} is below the baseline ${pct(baseline.passRate)} minus a margin of ${pct(margin)} (${pct(floor)}).`);
      exitCode = Math.max(exitCode, 1);
    }
  } else {
    messages.push('No baseline to compare with. Record one with --write-baseline.');
  }
  if (!messages.length) messages.push(`OK: pass rate ${pct(summary.passRate)}, baseline ${pct(baseline.passRate)}, margin ${pct(margin)}.`);
  return { exitCode, messages };
}

const pct = (x) => `${(x * 100).toFixed(1)}%`;

function baselineFrom(summary, now = new Date()) {
  const failedSkills = Object.fromEntries(Object.entries(summary.bySkill).filter(([, s]) => s.fail > 0).map(([k, s]) => [k, s]));
  return {
    recordedAt: now.toISOString().slice(0, 10),
    model: summary.model,
    copilotVersion: summary.copilotVersion,
    runs: summary.runs,
    passed: summary.passed,
    failed: summary.failed,
    passRate: Number(summary.passRate.toFixed(4)),
    credits: Number(summary.credits.toFixed(2)),
    skillsWithFailures: failedSkills,
  };
}

function main(argv) {
  const args = argv.slice(2);
  const file = args.find((a) => !a.startsWith('--') && args[args.indexOf(a) - 1] !== '--baseline' && args[args.indexOf(a) - 1] !== '--margin');
  const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
  if (!file) {
    console.error('Usage: node scripts/thresholds.js <results.json> [--baseline <file>] [--margin <0-1>] [--write-baseline]');
    return 2;
  }
  let summary;
  try {
    summary = summarise(rowsFrom(JSON.parse(fs.readFileSync(file, 'utf8'))));
  } catch (error) {
    console.error(`Could not read ${file}: ${error.message}`);
    return 2;
  }
  const baselineFile = option('--baseline') ?? DEFAULT_BASELINE;
  console.log(`${summary.passed} passed, ${summary.failed} failed, ${summary.errors} errors of ${summary.runs} runs. Pass rate ${pct(summary.passRate)}. Credits ${summary.credits.toFixed(1)}.`);
  for (const [skill, s] of Object.entries(summary.bySkill)) if (s.fail || s.error) console.log(`  ${skill}: ${s.pass} passed, ${s.fail} failed, ${s.error} errors`);
  if (args.includes('--write-baseline')) {
    if (summary.errors > 0) {
      console.error('Not writing a baseline from a run with provider errors.');
      return 2;
    }
    fs.mkdirSync(path.dirname(baselineFile), { recursive: true });
    fs.writeFileSync(baselineFile, `${JSON.stringify(baselineFrom(summary), null, 2)}\n`);
    console.log(`Wrote ${baselineFile}`);
    return 0;
  }
  const baseline = fs.existsSync(baselineFile) ? JSON.parse(fs.readFileSync(baselineFile, 'utf8')) : undefined;
  const margin = option('--margin') === undefined ? DEFAULT_MARGIN : Number(option('--margin'));
  const { exitCode, messages } = evaluate(summary, baseline, margin);
  for (const message of messages) console.log(message);
  return exitCode;
}

if (require.main === module) process.exitCode = main(process.argv);

module.exports = { rowsFrom, summarise, evaluate, baselineFrom, skillsAllFailed, DEFAULT_MARGIN };
