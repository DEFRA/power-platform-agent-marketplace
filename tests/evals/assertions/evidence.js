'use strict';
// Shared assertions over the evidence the provider puts in `metadata`.
// Each check is a pure function of (metadata, args) that returns { pass, reason }, so it can be unit tested.
// The promptfoo wrappers at the bottom read `context.providerResponse.metadata` and the assertion's `config`.
// In a case file:  - type: javascript
//                    value: file://assertions/evidence.js:skillLoaded
//                    config: { skill: adr }

const toArray = (value) => (value === undefined || value === null ? [] : [].concat(value));
const normalise = (p) => String(p).split('\\').join('/').replace(/^\.\//, '');

/** Glob to regular expression: `**` crosses folders, `*` and `?` stay within one. */
function globToRegExp(glob) {
  const g = normalise(glob);
  let out = '';
  for (let i = 0; i < g.length; i++) {
    if (g.startsWith('**/', i)) {
      out += '(?:.*/)?';
      i += 2;
    } else if (g.startsWith('**', i)) {
      out += '.*';
      i += 1;
    } else if (g[i] === '*') out += '[^/]*';
    else if (g[i] === '?') out += '[^/]';
    else out += '.+^${}()|[]\\'.includes(g[i]) ? `\\${g[i]}` : g[i];
  }
  return new RegExp(`^${out}$`, 'i');
}

const matchesAny = (file, globs) => globs.some((g) => globToRegExp(g).test(normalise(file)));
const pass = (reason = 'ok') => ({ pass: true, score: 1, reason });
const fail = (reason) => ({ pass: false, score: 0, reason });
const list = (items) => (items.length ? items.join(', ') : 'none');

const changedPaths = (m) => (m.filesChanged || []).map((f) => f.path);

function skillLoaded(m, { skill }) {
  const loaded = m.skillsLoaded || [];
  return loaded.includes(skill)
    ? pass(`Loaded ${skill}. Skills loaded, in order: ${list(loaded)}. Route: ${m.route ?? 'none'}`)
    : fail(`Expected skill ${skill} to be loaded. Skills loaded: ${list(loaded)}. Tool calls: ${list((m.toolCalls || []).map((c) => c.name))}`);
}

function skillNotLoaded(m, { skill }) {
  const loaded = m.skillsLoaded || [];
  return loaded.includes(skill) ? fail(`Skill ${skill} was loaded. Skills loaded: ${list(loaded)}`) : pass(`${skill} not loaded`);
}

function noFilesChanged(m) {
  const paths = changedPaths(m);
  return paths.length ? fail(`Expected no files to change. Changed: ${list(paths)}`) : pass('No files changed');
}

function onlyFilesChanged(m, { globs }) {
  const allowed = toArray(globs);
  const outside = changedPaths(m).filter((p) => !matchesAny(p, allowed));
  return outside.length ? fail(`Files changed outside ${list(allowed)}: ${list(outside)}`) : pass(`Changed: ${list(changedPaths(m))}`);
}

function noFilesChangedUnder(m, { globs }) {
  const forbidden = toArray(globs);
  const hit = changedPaths(m).filter((p) => matchesAny(p, forbidden));
  return hit.length ? fail(`Files changed under ${list(forbidden)}: ${list(hit)}`) : pass(`Nothing changed under ${list(forbidden)}`);
}

function headNotMoved(m) {
  return m.headMoved ? fail('HEAD moved from the baseline commit') : pass('HEAD not moved');
}

/** Git subcommands in a shell command line, skipping global options such as `--no-optional-locks`, `-c k=v` and `-C path`. */
function gitSubcommands(command) {
  const found = [];
  const pattern = /(?:^|[\s;&|(])git(?:\.exe)?((?:\s+(?:-[cC]\s+\S+|--[\w-]+(?:=\S+)?))*)\s+([a-z][\w-]*)/gi;
  for (const match of String(command).matchAll(pattern)) found.push(match[2].toLowerCase());
  return found;
}

function noGitCommand(m, { subcommands }) {
  const forbidden = toArray(subcommands).map((s) => s.toLowerCase());
  const hits = [];
  for (const command of m.commands || []) {
    for (const sub of gitSubcommands(command)) if (forbidden.includes(sub)) hits.push(`git ${sub} (in: ${String(command).slice(0, 120)})`);
  }
  return hits.length ? fail(`Forbidden git commands ran: ${hits.join('; ')}`) : pass(`No git ${list(forbidden)} commands. Commands run: ${(m.commands || []).length}`);
}

function replyMentionsAgent(output, { agent }) {
  const bare = String(agent).replace(/^.*:/, '');
  // The id is kebab-case, so a plain word-boundary check is enough: the neighbours may not be a letter, digit, _ or -.
  const isIdChar = (c) => c !== undefined && /[A-Za-z0-9_-]/.test(c);
  const text = String(output);
  let at = text.indexOf(bare);
  let found = false;
  while (at !== -1 && !found) {
    found = !isIdChar(text[at - 1]) && !isIdChar(text[at + bare.length]);
    at = text.indexOf(bare, at + 1);
  }
  return found
    ? pass(`Reply mentions ${bare}`)
    : fail(`Reply doesn't mention agent ${bare}. Reply began: ${String(output).slice(0, 200)}`);
}

const REPORT_FIELDS = ['STATUS', 'SUMMARY', 'FILES CHANGED', 'CHECKS', 'DEVIATIONS', 'QUESTIONS'];

/** The fixed report in agents/developer-worker.agent.md: six fields, in order, each at the start of a line. */
function replyMatchesWorkerReport(output, { status } = {}) {
  const text = String(output);
  let from = 0;
  for (const field of REPORT_FIELDS) {
    const match = new RegExp(`^${field}:`, 'm').exec(text.slice(from));
    if (!match) return fail(`Worker report is missing "${field}:" (or it is out of order). Reply began: ${text.slice(0, 200)}`);
    from += match.index + match[0].length;
  }
  const statusValue = /^STATUS:\s*(DONE|BLOCKED|FAILED)\b/m.exec(text);
  if (!statusValue) return fail('STATUS must be DONE, BLOCKED or FAILED');
  if (status && statusValue[1] !== status) return fail(`Expected STATUS: ${status}, got ${statusValue[1]}`);
  return pass(`Worker report is well formed, STATUS: ${statusValue[1]}`);
}

/** Wrap a check for promptfoo. Checks on evidence get `metadata`, checks on the reply get `output`. */
function wrap(check, source) {
  return (output, context) => {
    const metadata = context?.providerResponse?.metadata;
    if (source === 'metadata' && !metadata) return fail('No metadata on the provider response');
    return check(source === 'metadata' ? metadata : output, context?.config || {});
  };
}

module.exports = {
  // pure checks, for unit tests
  checks: { skillLoaded, skillNotLoaded, noFilesChanged, onlyFilesChanged, noFilesChangedUnder, headNotMoved, noGitCommand, replyMentionsAgent, replyMatchesWorkerReport },
  globToRegExp,
  gitSubcommands,
  // promptfoo assertions
  skillLoaded: wrap(skillLoaded, 'metadata'),
  skillNotLoaded: wrap(skillNotLoaded, 'metadata'),
  // For a case file whose tests name the expected skill in `vars.skill`, so one defaultTest assertion serves every case.
  skillLoadedFromVars: (output, context) => {
    const metadata = context?.providerResponse?.metadata;
    if (!metadata) return fail('No metadata on the provider response');
    if (!context?.vars?.skill) return fail('The case has no vars.skill');
    return skillLoaded(metadata, { skill: context.vars.skill });
  },
  noFilesChanged: wrap(noFilesChanged, 'metadata'),
  onlyFilesChanged: wrap(onlyFilesChanged, 'metadata'),
  noFilesChangedUnder: wrap(noFilesChangedUnder, 'metadata'),
  headNotMoved: wrap(headNotMoved, 'metadata'),
  noGitCommand: wrap(noGitCommand, 'metadata'),
  replyMentionsAgent: wrap(replyMentionsAgent, 'output'),
  replyMatchesWorkerReport: wrap(replyMatchesWorkerReport, 'output'),
};
