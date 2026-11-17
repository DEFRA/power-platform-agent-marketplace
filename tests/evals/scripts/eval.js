#!/usr/bin/env node
'use strict';
// Runs one eval suite locally with the options a run always needs.
//
//   node scripts/eval.js routing|behaviour [promptfoo options, for example --filter-pattern "adr" or --repeat 3]
//
// Behaviour cases run three times unless --repeat says otherwise, because one run of a non-deterministic agent proves little.
//
// Caching, telemetry and update checks are off, parallelism is capped, nothing is shared to a hosted service, and
// results go to results/ (git-ignored) as JSON and HTML.
// Authentication comes from COPILOT_GITHUB_TOKEN, GH_TOKEN
// or GITHUB_TOKEN. This script never prints a token.

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

// Runs wait on the network, so they parallelise well. Each one starts a Copilot CLI process, so keep it modest.
const DEFAULT_CONCURRENCY = 8;
const DEFAULT_REPEATS = { behaviour: 3 };
const root = path.join(__dirname, '..');
const suite = process.argv[2];
const extra = process.argv.slice(3);

if (!suite || !fs.existsSync(path.join(root, `promptfooconfig.${suite}.yaml`))) {
  console.error('Usage: node scripts/eval.js <suite> [promptfoo options]. Suites with a config: routing, behaviour.');
  process.exit(2);
}

// The package doesn't export package.json, so read it from node_modules directly.
const packageFile = path.join(root, 'node_modules', 'promptfoo', 'package.json');
if (!fs.existsSync(packageFile)) {
  console.error('promptfoo is not installed. Run `npm ci` in tests/evals first.');
  process.exit(2);
}
const bin = require(packageFile).bin;
const entry = path.join(path.dirname(packageFile), typeof bin === 'string' ? bin : bin.promptfoo);

const results = path.join(root, 'results');
fs.mkdirSync(results, { recursive: true });
const json = path.join(results, `${suite}.json`);
const args = [
  entry, 'eval', '-c', `promptfooconfig.${suite}.yaml`, '--no-cache', '--no-write', '--no-share', ...(extra.some((a) => a === '--max-concurrency' || a === '-j') ? [] : ['--max-concurrency', String(DEFAULT_CONCURRENCY)]),
  ...(DEFAULT_REPEATS[suite] && !extra.some((a) => a === '--repeat' || a.startsWith('--repeat=')) ? ['--repeat', String(DEFAULT_REPEATS[suite])] : []),
  '-o', json, '-o', path.join(results, `${suite}.html`), ...extra,
];
const env = { ...process.env, PROMPTFOO_DISABLE_TELEMETRY: '1', PROMPTFOO_DISABLE_UPDATE: '1', PROMPTFOO_DISABLE_SHARING: '1' };

// Exit code: 0 when every case passed, 100 when some failed, anything else when the run itself broke.
const run = spawnSync(process.execPath, args, { cwd: root, env, stdio: 'inherit' });
process.exit(run.error ? 2 : run.status ?? 2);
