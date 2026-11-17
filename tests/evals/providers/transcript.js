'use strict';
// Pure functions that turn a Copilot CLI JSONL transcript and usage file into evidence.
// Unknown event types are ignored, because the CLI's format changes between versions.
// Tool names differ by model and operating system, so shell detection is deliberately tolerant.

const SHELL_TOOLS = new Set(['powershell', 'bash', 'shell', 'sh', 'pwsh', 'cmd', 'run_in_terminal']);
const NANO_PER_CREDIT = 1e9;

function parseLines(text) {
  const events = [];
  for (const line of String(text || '').split(/\r?\n/)) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line);
      if (event && typeof event === 'object') events.push(event);
    } catch {
      // A truncated or non-JSON line is skipped.
    }
  }
  return events;
}

function mainArgument(args) {
  if (!args || typeof args !== 'object') return '';
  const value = args.command ?? args.path ?? args.pattern ?? args.skill ?? args.paths ?? args.query ?? args.filePath ?? '';
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function toolCallFrom(event) {
  const data = event.data || {};
  const args = data.arguments && typeof data.arguments === 'object' ? data.arguments : {};
  return { name: String(data.toolName ?? ''), argument: mainArgument(args), arguments: args };
}

function isShellTool(name) {
  return SHELL_TOOLS.has(String(name).toLowerCase());
}

/** The route: the first skill loaded after the shared standards skill, or undefined. */
function routeOf(skillsLoaded, sharedSkill = 'power-platform-standards') {
  return (skillsLoaded || []).find((s) => s !== sharedSkill);
}

/** Evidence from a whole transcript. */
function parseTranscript(text) {
  const events = parseLines(text);
  const toolCalls = [];
  const subagents = [];
  const errors = [];
  let output = '';
  let result;
  let copilotVersion;
  for (const event of events) {
    const data = event.data || {};
    switch (event.type) {
      case 'session.start':
        copilotVersion = data.copilotVersion ?? copilotVersion;
        break;
      case 'tool.execution_start':
        toolCalls.push(toolCallFrom(event));
        break;
      case 'assistant.message':
        // Messages that only carry tool requests have empty content, so keep the last non-empty reply.
        if (typeof data.content === 'string' && data.content.trim()) output = data.content;
        break;
      case 'subagent.started': {
        const id = data.agentName ?? data.agentId ?? data.name;
        if (id) subagents.push(String(id));
        break;
      }
      case 'session.error':
        errors.push({ type: data.errorType, message: data.message });
        break;
      case 'result':
        result = event;
        break;
      default:
        break;
    }
  }
  const skillsLoaded = toolCalls
    .filter((c) => c.name === 'skill' && typeof c.arguments.skill === 'string')
    .map((c) => c.arguments.skill);
  return {
    output,
    toolCalls: toolCalls.map(({ name, argument }) => ({ name, argument })),
    skillsLoaded,
    route: routeOf(skillsLoaded) ?? null,
    commands: toolCalls.filter((c) => isShellTool(c.name)).map((c) => c.argument),
    subagents,
    errors,
    quotaExceeded: errors.some((e) => e.type === 'quota'),
    exitCode: result?.exitCode,
    finished: Boolean(result),
    copilotVersion,
  };
}

/** Credits and tokens from a `--usage-output-file` file. Returns undefined when the file is missing or unreadable. */
function parseUsage(text) {
  let usage;
  try {
    usage = JSON.parse(text);
  } catch {
    return undefined;
  }
  if (!usage || typeof usage !== 'object') return undefined;
  const toCredits = (nano) => (typeof nano === 'number' ? nano / NANO_PER_CREDIT : 0);
  const byAgent = {};
  for (const [agent, metrics] of Object.entries(usage.agentMetrics || {})) {
    byAgent[agent] = toCredits(metrics?.totalNanoAiu);
  }
  let input = 0;
  let output = 0;
  for (const m of Object.values(usage.modelMetrics || {})) {
    input += m?.usage?.inputTokens ?? 0;
    output += m?.usage?.outputTokens ?? 0;
  }
  return {
    credits: toCredits(usage.totalNanoAiu),
    byAgent,
    premiumRequests: usage.totalPremiumRequestCost ?? 0,
    tokenUsage: { prompt: input, completion: output, total: input + output },
  };
}

module.exports = { parseLines, parseTranscript, parseUsage, routeOf, isShellTool };
