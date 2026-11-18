'use strict';
// promptfoo provider that runs GitHub Copilot CLI headlessly against the plugin.
// Every run goes to its natural end, so the usage file is always written. The provider reads standard output
// as it arrives only so that it can enforce timeoutMs.

const fs = require('node:fs');
const path = require('node:path');
const childProcess = require('node:child_process');
const { parseTranscript, parseUsage } = require('./transcript');
const { locateCopilot, runProcess } = require('./process');
const { prepareWorkspace, removeFolder, gitEvidence } = require('./workspace');

const EVALS_ROOT = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(EVALS_ROOT, '..', '..');
const TOKEN_VARIABLES = ['COPILOT_GITHUB_TOKEN', 'GH_TOKEN', 'GITHUB_TOKEN'];
const MIN_CREDITS = 30; // --max-ai-credits rejects anything lower
const DEFAULTS = { pluginDir: 'plugins/power-platform-delivery', maxCredits: MIN_CREDITS, timeoutMs: 300000 };
// Keys that a test's `vars` may override. `prompt` is not one of them.
const CONFIG_KEYS = ['pluginDir', 'agent', 'model', 'fixture', 'overlay', 'maxCredits', 'autopilot', 'allowTools', 'denyTools', 'timeoutMs'];

const asList = (value) => (value === undefined || value === null || value === '' ? [] : [].concat(value).map(String));

/** Provider config with per-test overrides from `vars`. Throws a clear message for an unusable configuration. */
function resolveConfig(providerConfig = {}, vars = {}) {
  const config = { ...DEFAULTS, ...providerConfig };
  // A grader sets `ignoreVars`, because promptfoo hands it the graded case's vars, which would change its agent and fixture.
  for (const key of config.ignoreVars ? [] : CONFIG_KEYS) {
    if (vars[key] !== undefined && vars[key] !== '') config[key] = vars[key];
  }
  if (!config.model) throw new Error('config.model is required, so a run never depends on the CLI default.');
  config.maxCredits = Number(config.maxCredits);
  if (!(config.maxCredits >= MIN_CREDITS)) {
    throw new Error(`config.maxCredits must be a number of at least ${MIN_CREDITS}, because --max-ai-credits rejects less.`);
  }
  return config;
}

/** The Copilot CLI arguments for one run. Pure, and the prompt is one array element so quoting can't break it. */
function buildArgs(config, prompt, { pluginDir, usageFile }) {
  const args = ['-p', String(prompt), '--output-format', 'json', '--no-ask-user', '--no-custom-instructions'];
  if (pluginDir) args.push('--plugin-dir', pluginDir); // an empty pluginDir runs with no plugin, as the judge does
  args.push('--model', String(config.model));
  args.push('--max-ai-credits', String(config.maxCredits), '--usage-output-file', usageFile);
  if (config.agent) args.push('--agent', String(config.agent));
  if (config.autopilot) {
    args.push('--autopilot');
    if (typeof config.autopilot !== 'boolean' && Number.isFinite(Number(config.autopilot)) && Number(config.autopilot) > 0) {
      args.push('--max-autopilot-continues', String(Number(config.autopilot)));
    }
  }
  // The = form keeps each rule a single argument, so a variadic option can't swallow what follows.
  for (const tool of asList(config.allowTools)) args.push(`--allow-tool=${tool}`);
  for (const tool of asList(config.denyTools)) args.push(`--deny-tool=${tool}`);
  return args;
}

const resolveFrom = (base, value) => (value ? path.resolve(base, String(value)) : '');

class CopilotCliProvider {
  /** `options.deps` replaces collaborators in unit tests: run, locate, version, env, platform, prepare, cleanup, gitEvidence. */
  constructor(options = {}) {
    this.config = options.config || {};
    this.deps = options.deps || {};
    this.preflightResult = undefined;
  }

  id() {
    return 'copilot-cli';
  }

  /** Checks that the CLI is installed and a token is set. Done once per provider, and reports problems in plain words. */
  preflight() {
    if (this.preflightResult) return this.preflightResult;
    const env = this.deps.env ?? process.env;
    const platform = this.deps.platform ?? process.platform;
    const result = {};
    try {
      result.launcher = (this.deps.locate ?? locateCopilot)({ platform, env });
      const probe = this.deps.version ?? ((l) => childProcess.spawnSync(l.command, [...l.prefixArgs, '--version'], { encoding: 'utf8', windowsHide: true, shell: false }));
      const out = probe(result.launcher);
      if (out.error || out.status !== 0) throw new Error(`Copilot CLI did not run: ${out.error ? out.error.message : (out.stderr || '').trim() || `exit ${out.status}`}`);
      result.version = (String(out.stdout).match(/\d+\.\d+\.\d+/) || [''])[0];
      if (!TOKEN_VARIABLES.some((name) => env[name])) {
        throw new Error(`Not authenticated. Set one of ${TOKEN_VARIABLES.join(', ')} in the environment (a stored login isn't visible, because runs use an isolated COPILOT_HOME).`);
      }
    } catch (error) {
      result.error = error.message;
    }
    this.preflightResult = result;
    return result;
  }

  async callApi(prompt, context) {
    const vars = (context && context.vars) || {};
    if (vars.replay || this.config.replay) return this.replay(vars.replay || this.config.replay);

    let config;
    try {
      config = resolveConfig(this.config, vars);
    } catch (error) {
      return { error: error.message };
    }
    const pre = this.preflight();
    if (pre.error) return { error: pre.error };

    const env = this.deps.env ?? process.env;
    const pluginDir = resolveFrom(REPO_ROOT, config.pluginDir);
    if (pluginDir && !fs.existsSync(pluginDir)) return { error: `pluginDir does not exist: ${pluginDir}` };
    const fixture = resolveFrom(EVALS_ROOT, config.fixture);
    const overlay = resolveFrom(EVALS_ROOT, config.overlay);

    let workspace;
    try {
      workspace = (this.deps.prepare ?? prepareWorkspace)({ fixture, overlay });
    } catch (error) {
      return { error: `Could not prepare the working folder: ${error.message}` };
    }
    try {
      const args = buildArgs(config, prompt, { pluginDir, usageFile: workspace.usageFile });
      const childEnv = { ...env, COPILOT_HOME: workspace.copilotHome, NO_COLOR: '1' };
      const run = await (this.deps.run ?? runProcess)({
        command: pre.launcher.command,
        args: [...pre.launcher.prefixArgs, ...args],
        cwd: workspace.dir,
        env: childEnv,
        timeoutMs: Number(config.timeoutMs),
      });
      return this.respond(run, workspace, config, pre.version);
    } finally {
      if (!process.env.COPILOT_EVAL_KEEP_TEMP) (this.deps.cleanup ?? removeFolder)(workspace.root);
      else console.error(`Kept the working folder: ${workspace.root}`);
    }
  }

  respond(run, workspace, config, cliVersion) {
    const evidence = parseTranscript(run.stdout);
    let usageText = '';
    try {
      usageText = fs.readFileSync(workspace.usageFile, 'utf8');
    } catch {
      // No usage file: the process was killed, or never started.
    }
    const usage = parseUsage(usageText);
    const git = (this.deps.gitEvidence ?? gitEvidence)(workspace.dir, workspace.baseline, workspace.overlayState);
    const metadata = {
      ...evidence,
      ...git,
      credits: usage ? { total: usage.credits, byAgent: usage.byAgent, premiumRequests: usage.premiumRequests } : undefined,
      copilotVersion: cliVersion || evidence.copilotVersion,
      model: config.model,
      agent: config.agent || undefined,
    };
    const response = { output: evidence.output, metadata };
    if (usage) response.tokenUsage = usage.tokenUsage;
    const error = this.errorFor(run, evidence, config);
    if (error) response.error = error;
    return response;
  }

  /** A run that didn't complete is a provider error, so it is never counted as a failed assertion. */
  errorFor(run, evidence, config) {
    if (run.spawnError) return `Could not start Copilot CLI: ${run.spawnError}`;
    if (run.timedOut) return `Timed out after ${config.timeoutMs} ms and the process tree was ended.`;
    if (evidence.quotaExceeded) return 'Copilot quota exhausted (session.error errorType "quota").';
    if (run.exitCode !== 0 || !evidence.finished) {
      const detail = evidence.errors.map((e) => `${e.type ?? 'error'}: ${e.message ?? ''}`).join('; ') || run.stderrTail.trim().slice(-500);
      const why = run.exitCode !== 0 ? `exited with code ${run.exitCode}` : 'ended without a result event';
      return `Copilot CLI ${why}${detail ? `. ${detail}` : ''}`;
    }
    return undefined;
  }

  /** Offline mode: parse a recording instead of running the CLI. Used to try assertions without a model. */
  replay(file) {
    const text = fs.readFileSync(path.resolve(__dirname, file), 'utf8');
    const evidence = parseTranscript(text);
    return { output: evidence.output, metadata: { ...evidence, filesChanged: [], headMoved: false, diff: '' } };
  }
}

module.exports = CopilotCliProvider;
module.exports.resolveConfig = resolveConfig;
module.exports.buildArgs = buildArgs;
module.exports.MIN_CREDITS = MIN_CREDITS;
