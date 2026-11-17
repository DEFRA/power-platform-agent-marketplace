# Evals

Evals for the `power-platform-delivery` plugin. They run GitHub Copilot CLI headlessly against the plugin, on [promptfoo](https://www.promptfoo.dev/). They cost Copilot credits and are non-deterministic, so they run on a developer's machine only, never in CI, and they don't gate pull requests or releases. The expectation is that every case passes. A failure is a finding to read, not a number to tune.

Only the routing suite exists so far: does a natural prompt load the intended skill?

## Prerequisites

- Node 20 or later, and `npm ci` in this folder.
- Copilot CLI, installed with `npm install -g @github/copilot`. Developed against 1.0.112 and 1.0.113. The CLI updates itself, and a run that overlaps an update fails with "no platform package found". That is reported as an error, so rerun.
- A token in `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` or `GITHUB_TOKEN`. Runs use an isolated `COPILOT_HOME`, so a stored `copilot login` isn't used. Never print or commit a token.
- Tested on Windows only. Linux and macOS are untested: the provider starts `copilot` directly there, and the tool names (`powershell`, `apply_patch` and the `shell` and `write` deny rules) may differ.

## Run

```powershell
npm run eval:routing                                  # all 40 cases, 10 to 11 minutes at 4 parallel runs
npm run eval:routing -- --filter-pattern "adr"        # one skill
npm run eval:routing -- --repeat 3                    # repeat each case
npm run eval:routing -- --max-concurrency 4           # default is 8 parallel runs
npm run test:unit                                     # provider and assertion unit tests, no credentials
```

Results go to `results/` (git-ignored) as JSON and HTML. The exit code is 0 when every case passed, 100 when some failed, and 2 or another value when the run itself broke. A run that ends in a provider error (time-out, credit cap, quota, authentication, CLI update) is an error, not a failed assertion.

Cost, measured on `gpt-6-luna`: about 0.5 credits per routing case, 19 credits for the 40 cases. Each run is capped at 30 credits, the lowest value `--max-ai-credits` accepts.

## How a run works

For each case the provider (`providers/copilot-cli.js`):

1. Copies the fixture into a temporary folder, commits it as a baseline, and copies any overlay on top, uncommitted.
2. Starts `copilot` there, with an empty temporary `COPILOT_HOME`, `--plugin-dir`, `--model`, `--output-format json`, `--no-ask-user`, `--no-custom-instructions`, `--max-ai-credits` and `--usage-output-file`. On Windows it runs `node` on the npm loader instead of the `.cmd` shim, because the shim mangles a prompt that contains spaces. It never uses a shell.
3. Lets the run reach its natural end, reading output as it arrives so that `timeoutMs` can end the whole process tree (`taskkill /T /F` on Windows, the process group elsewhere).
4. Returns the final reply, token usage and evidence in `metadata`, then deletes the temporary folders.

Config keys, from the provider `config` block and overridable per case in `vars`: `pluginDir` (relative to the repository root, defaults to the plugin), `agent` (the namespaced id, `power-platform-delivery:<id>`, or empty), `model` (required), `fixture` and `overlay` (relative to this folder), `maxCredits`, `autopilot` (`true` or a continuation limit), `allowTools`, `denyTools` and `timeoutMs`.

Evidence in `metadata`: `skillsLoaded`, `route` (the first skill loaded after `power-platform-standards`), `toolCalls`, `commands`, `subagents`, `filesChanged`, `headMoved`, `diff`, `credits` (by agent), `exitCode`, `copilotVersion` and `model`. A denied tool call still appears as a call, so `toolCalls` lists attempts. What changed comes from git. Unknown transcript event types are ignored, and tool names differ by model and operating system.

Assertions are in `assertions/evidence.js`, used as `file://assertions/evidence.js:<name>` with arguments in the assertion's `config`: `skillLoaded`, `skillNotLoaded`, `skillLoadedFromVars`, `noFilesChanged`, `onlyFilesChanged`, `noFilesChangedUnder`, `headNotMoved`, `noGitCommand`, `replyMentionsAgent` and `replyMatchesWorkerReport`.

## Writing cases

- Write prompts as a user would, in the neutral domain (Case, Applicant, Inspection, prefix `abc_`). Don't quote a skill's `description`.
- **Limit the tools and say so in the prompt.** Evals deny `shell` and `write`, so a run can't change anything. Every prompt ends by telling the agent this ("This is a read-only session: you can't run commands or change files. Say what you would do, rather than doing it."), so it describes its intentions instead of trying the work and reporting a denial. Do the same for behaviour cases. Don't mention skills in that sentence, because it would lead the routing.
- Routing cases are positive only: two prompts per skill, except `power-platform-standards`, which is loaded first by design and is never asserted absent. A case passes when the expected skill is loaded anywhere in the run, because a run may reasonably load another skill first (`architecture-review` before `dataverse-plugins`, for example).
- Run with no `--agent` for routing, so the test is of the skill descriptions alone.
- When a case fails, decide which is wrong: the skill's `description` or the case. Fix the description if a real user's prompt wouldn't find the skill. Don't reword a case until it passes. A change to a description is a plugin behaviour change and needs its own changelog entry.

## Model

Evals pin `gpt-6-luna`: cheap, and it loads skills reliably. Haiku 5.5 and several other models rarely called the `skill` tool unprompted, so they tested the model and not the instructions. A case that passes only on a stronger model is still a finding about the instructions. Results vary between runs of the same case, so use `--repeat` before drawing conclusions from one failure.

## Safety

- Each run happens in a temporary copy of the fixture, never in this repository. `--allow-all-paths` is never passed.
- The child process inherits the caller's environment, including the token, so allowing a shell tool would expose it. Routing denies shell.
- Set `COPILOT_EVAL_KEEP_TEMP=1` to keep a run's working folder for debugging.
- Results are never shared to a hosted service. Telemetry and update checks are off.
- Scrub recordings before committing them: tool results can carry machine paths and the account's remaining budget. Recordings in `providers/recordings/` have been scrubbed, and their `assistant.tool_call_delta` lines removed.
- On Windows PowerShell, redirecting standard error with `2>` can produce UTF-16. Redirect standard output only when capturing a transcript.

## Layout

| Path                           | Purpose                                                           |
| ------------------------------ | ----------------------------------------------------------------- |
| `providers/copilot-cli.js`     | The promptfoo provider                                            |
| `providers/process.js`         | Finding Copilot CLI, starting it without a shell, ending its tree |
| `providers/workspace.js`       | The temporary repository and the git evidence                     |
| `providers/transcript.js`      | Pure parsing of the JSONL transcript and usage file               |
| `providers/recordings/`        | Scrubbed transcripts that the unit tests use                      |
| `assertions/evidence.js`       | Shared assertions over the provider's `metadata`                  |
| `cases/routing.yaml`           | The routing cases                                                 |
| `promptfooconfig.routing.yaml` | The routing suite's config                                        |
| `scripts/eval.js`              | The run command                                                   |
