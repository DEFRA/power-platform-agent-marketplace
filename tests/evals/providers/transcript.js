'use strict';
// Pure functions that turn a Copilot CLI JSONL transcript into evidence. Unknown event types are ignored.

const SHELL_TOOLS = new Set(['powershell', 'bash', 'shell', 'sh']);

function parseLines(text) {
  const events = [];
  for (const line of String(text || '').split(/\r?\n/)) {
    if (!line.trim()) continue;
    try {
      events.push(JSON.parse(line));
    } catch {
      // A truncated or non-JSON line is skipped.
    }
  }
  return events;
}

function mainArgument(args) {
  if (!args || typeof args !== 'object') return '';
  return args.command ?? args.path ?? args.pattern ?? args.skill ?? args.paths ?? '';
}

function toolCallFrom(event) {
  const data = event.data || {};
  return { name: data.toolName, argument: mainArgument(data.arguments), arguments: data.arguments };
}

function skillName(call) {
  return call.name === 'skill' ? call.arguments?.skill : undefined;
}

/** Evidence from a whole transcript. */
function parseTranscript(text) {
  const events = parseLines(text);
  const toolCalls = [];
  let output = '';
  let result;
  const errors = [];
  for (const event of events) {
    if (event.type === 'tool.execution_start') toolCalls.push(toolCallFrom(event));
    else if (event.type === 'assistant.message' && event.data?.content) output = event.data.content;
    else if (event.type === 'session.error') errors.push({ type: event.data?.errorType, message: event.data?.message });
    else if (event.type === 'result') result = event;
  }
  return {
    output,
    toolCalls: toolCalls.map(({ name, argument }) => ({ name, argument })),
    skillsLoaded: toolCalls.map(skillName).filter(Boolean),
    commands: toolCalls.filter((c) => SHELL_TOOLS.has(c.name)).map((c) => c.argument),
    subagents: [],
    errors,
    exitCode: result?.exitCode,
    finished: Boolean(result),
  };
}

/** The route: the first skill loaded after the shared standards skill, or undefined. */
function routeOf(skillsLoaded, sharedSkill = 'power-platform-standards') {
  return skillsLoaded.find((s) => s !== sharedSkill);
}

module.exports = { parseLines, parseTranscript, routeOf };
