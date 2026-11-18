# Evals

Evals for the `power-platform-delivery` plugin. They run GitHub Copilot CLI headlessly against the plugin, on [promptfoo](https://www.promptfoo.dev/). They cost Copilot credits and are non-deterministic, so they run on a developer's machine only, never in CI, and they don't gate pull requests or releases. The expectation is that every case passes. A failure is a finding to read, not a number to tune.

There are two suites:

- **Routing:** does a natural prompt load the intended skill?
- **Behaviour:** does an agent keep the rules its file states, such as stopping for approval or leaving production code alone? 14 cases, each run once by default, against `fixtures/consumer-repo`.

## Prerequisites

- Node 22 or later, and `npm ci` in this folder.
- Copilot CLI, installed with `npm install -g @github/copilot`. Developed against 1.0.112 and 1.0.113. The CLI updates itself, and a run that overlaps an update fails with "no platform package found". That is reported as an error, so rerun.
- A token in `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` or `GITHUB_TOKEN`. Runs use an isolated `COPILOT_HOME`, so a stored `copilot login` isn't used. Never print or commit a token.
- Tested on Windows only. Linux and macOS are untested: the provider starts `copilot` directly there, and the tool names (`powershell`, `apply_patch` and the `shell` and `write` deny rules) may differ.

## Run

```powershell
npm run eval:routing                                  # all 40 cases, about 4 minutes at 8 parallel runs
npm run eval:routing -- --filter-pattern "adr"        # one skill
npm run eval:routing -- --repeat 3                    # repeat each case
npm run eval:behaviour                                # 14 cases, one run each, about 3 minutes at 8 parallel runs
npm run eval:behaviour -- --filter-pattern "B-QE"     # one agent
npm run regrade -- results/behaviour.json --filter B-QE   # grade stored replies again, with no agent run
npm run eval:routing -- --var model=gpt-5.6-luna      # try another model (the report's label still shows the default, the model column the one used)
npm run eval:routing -- --max-concurrency 4           # the default is 8 parallel runs
npm run test:unit                                     # provider and assertion unit tests, no credentials
```

Results go to `results/` (git-ignored) as JSON and HTML. The exit code is 0 when every case passed, 100 when some failed, and 2 or another value when the run itself broke. A run that ends in a provider error (time-out, credit cap, quota, authentication, CLI update) is an error, not a failed assertion.

Cost, measured on `gpt-6-luna`: about 0.25 credits per routing case, 9.5 credits for the 40 cases. A behaviour run averages 0.5 credits and 40 to 60 seconds (22.8 credits and 7 minutes 38 seconds for the 45 runs). Grader calls (below) are extra and cost a few tenths of a credit each. Each run is capped at 30 credits, the lowest value `--max-ai-credits` accepts.

## How a run works

For each case the provider (`providers/copilot-cli.js`):

1. Copies the fixture into a temporary folder, commits it as a baseline, and copies any overlay on top, uncommitted.
2. Starts `copilot` there, with an empty temporary `COPILOT_HOME`, `--plugin-dir`, `--model`, `--output-format json`, `--no-ask-user`, `--no-custom-instructions`, `--max-ai-credits` and `--usage-output-file`. On Windows it runs `node` on the npm loader instead of the `.cmd` shim, because the shim mangles a prompt that contains spaces. It never uses a shell.
3. Lets the run reach its natural end, reading output as it arrives so that `timeoutMs` can end the whole process tree (`taskkill /T /F` on Windows, the process group elsewhere).
4. Returns the final reply, token usage and evidence in `metadata`, then deletes the temporary folders.

Config keys, from the provider `config` block and overridable per case in `vars`: `pluginDir` (relative to the repository root, defaults to the plugin), `agent` (the namespaced id, `power-platform-delivery:<id>`, or empty), `model` (required), `fixture` and `overlay` (relative to this folder), `maxCredits`, `autopilot` (`true` or a continuation limit), `allowTools`, `denyTools`, `timeoutMs` and `ignoreVars` (the case's `vars` don't override the config, which a grader needs).

Behaviour runs use the same provider with an agent (`vars.agent`), `fixture: fixtures/consumer-repo` and, for some cases, an `overlay` from `fixtures/overlays/`. The provider supports `autopilot`, but no case uses it: autopilot tells the agent to decide rather than ask, so the approval gate is not tested in it. In autopilot the agent's final reply is the summary of its `task_complete` call, which the provider reads. `developer-worker` pins its own model, so its cases run on that. Cases start the worker directly: delegation from `developer` to the worker, and so the `subagents` evidence, is untested.

Evidence in `metadata`: `skillsLoaded`, `route` (the first skill loaded after `power-platform-standards`), `toolCalls`, `commands`, `subagents`, `filesChanged` (changes made by the run, not those that an overlay put there), `headMoved`, `diff`, `credits` (by agent), `exitCode`, `copilotVersion` and `model`. A denied tool call still appears as a call, so `toolCalls` lists attempts. What changed comes from git. Unknown transcript event types are ignored, and tool names differ by model and operating system.

Assertions are in `assertions/evidence.js`, used as `file://assertions/evidence.js:<name>` with arguments in the assertion's `config`: `skillLoaded`, `skillNotLoaded`, `skillLoadedFromVars`, `noFilesChanged`, `onlyFilesChanged`, `noFilesChangedUnder`, `noWriteAttempts`, `writeAttemptsOnly`, `headNotMoved`, `noGitCommand`, `replyMentionsAgent`, `replyMatchesWorkerReport` (the six fields in order, the report only, 40 lines or fewer), `replyMatches` and `replyNotMatches`. What a reply says is graded with promptfoo's built-in `llm-rubric` assertion, described below.

## Writing cases

- Write prompts as a user would, in the neutral domain (Case, Applicant, Inspection, prefix `abc_`). Don't quote a skill's `description`.
- **Limit the tools and say so in the prompt.** Evals deny `shell` and `write`, so a run can't change anything. Every prompt ends by telling the agent this ("This is a read-only session: you can't run commands or change files. Say what you would do, rather than doing it."), so it describes its intentions instead of trying the work and reporting a denial. Behaviour cases use a different closing sentence, because "Say what you would do" invited a plan where an agent would normally have stopped to ask: "This is a read-only session: you can't run commands or change files. Reply as you normally would, and where you would have run a command or changed a file, say what you would have done instead." It names no behaviour under test. Don't mention skills, approvals or handoffs in either sentence, because that would lead the result.
- Routing cases are positive only: two prompts per skill, except `power-platform-standards`, which is loaded first by design and is never asserted absent. A case passes when the expected skill is loaded anywhere in the run, because a run may reasonably load another skill first (`architecture-review` before `dataverse-plugins`, for example).
- Run with no `--agent` for routing, so the test is of the skill descriptions alone.
- When a case fails, decide which is wrong: the skill's `description` or the case. Fix the description if a real user's prompt wouldn't find the skill. Don't reword a case until it passes. A change to a description is a plugin behaviour change and needs its own changelog entry.

## Behaviour cases

- **Read-only, with reads allowed.** Behaviour runs deny `shell` and `write`. The prompt ends with the read-only sentence, preceded by "You can read any file in the repository.", because with the read-only sentence alone agents decided they couldn't look at files and answered without evidence. The agent says what it would do. Evidence is its reply and the calls it attempted (a denied `edit`, `create` or `apply_patch` still appears in `toolCalls`). `noFilesChanged` runs on every case as a check that the denial held. Anything the agent would write to a file, such as a new ADR or the worker's report, is expected in the reply.
- **Name the skill.** When the quoted rule comes from a skill and not from the agent file, set `vars.skill` on the case. It is only a label: it adds a Skill column to the report table, and no assertion reads it. (Routing cases use the same var for the skill that must load.)
- **Quote the rule.** Every assertion comes from a sentence in an agent or skill file, quoted in the case's description. If there is no sentence, the case doesn't belong.
- **Deterministic first.** Use the checks on evidence where they can show the rule: skills loaded, attempted writes and git commands, the worker's report, an ADR number. Use an `llm-rubric` only where the rule is about what the reply says.
- **Rubrics are narrow and literal.** One `llm-rubric` per rule, written as the quoted sentence plus a yes or no question. The grader sees the user's request and the reply (not the tool calls, which the deterministic checks cover) and answers in JSON, using the `rubricPrompt` in the suite config. By default it is the same Copilot provider, with no plugin, no fixture and `ignoreVars` set so that the case's `vars` can't change it. A different grader, such as a Microsoft Foundry endpoint in CI, needs no change to the cases: pass `--grader <provider>` to `npm run eval:behaviour` or to `npm run regrade`. A grader is a model too: it can be stricter or looser from one call to the next, so read its stated reason before you read a failure as the agent's. `npm run regrade` grades stored replies again, so a changed rubric costs a few grader calls and not another run of the agents.
- **Expected status of a read-only worker.** A worker that can't edit reports `STATUS: BLOCKED`, so the cases that would otherwise end `DONE` expect `BLOCKED`. B-WRK-1 checks the report's shape and that only the allowed file was targeted.
- **The fixture has a planted defect.** `CaseNumberPlugin` allocates a number when the status is 3 (Approved) and a submitted Case has status 2. The triage and quality cases depend on it. The fixture has no `.agent-config/power-platform.json`, so project facts are discovered, and no case needs `dotnet`, `npm`, Dataverse or Azure Boards.
- **Every repeat of every case is expected to pass.** A failure is a finding. Decide whether the agent or skill text, or the case, is wrong, and say which. Hard cases (the rule is a prohibition or a stop) are the ones to read first.

## Model

Evals pin `gpt-6-luna`: cheap, and it loads skills reliably. Haiku 5.5 and several other models rarely called the `skill` tool unprompted, so they tested the model and not the instructions. A case that passes only on a stronger model is still a finding about the instructions. Results vary between runs of the same case, so use `--repeat` before drawing conclusions from one failure.

## Safety

- Each run happens in a temporary copy of the fixture, never in this repository. `--allow-all-paths` is never passed.
- The child process inherits the caller's environment, including the token, so allowing a shell tool would expose it. Routing and behaviour runs deny shell.
- Set `COPILOT_EVAL_KEEP_TEMP=1` to keep a run's working folder for debugging.
- Results are never shared to a hosted service. Telemetry and update checks are off.
- Scrub recordings before committing them: tool results can carry machine paths and the account's remaining budget. Recordings in `providers/recordings/` have been scrubbed, and their `assistant.tool_call_delta` lines removed.
- On Windows PowerShell, redirecting standard error with `2>` can produce UTF-16. Redirect standard output only when capturing a transcript.

## Things worth knowing

Found while building the evals, for whoever changes them next:

- **Before any case runs**, the provider checks that Copilot CLI runs and a token is set, and returns a plain error if not. A quota that is used up (exit 1 with a `session.error` of type `quota`) is reported as an error, not a failed case.
- **`--max-ai-credits` has a minimum of 30**, so every run is capped at 30 credits at least.
- **Plugin agents are namespaced** (`power-platform-delivery:<id>`). `developer-worker` runs when started directly although it isn't user-invocable, and runs on the model it pins. `metadata.model` shows the configured model, not necessarily the one the worker used. The usage file's model metrics do.
- **Tool names** seen on Windows: `powershell`, `edit`, `create`, `apply_patch`, `view`, `glob`, `grep`, `rg`, `skill`, `task_complete`. They differ by model and operating system, and `--deny-tool=write` denies `edit`, `create` and `apply_patch` together.
- **Autopilot** ends with a `task_complete` call, whose summary is the reply (the provider reads it). Its system notice tells the agent to "decide; don't ask", so an approval gate can't be tested under it, and no case uses it.
- **The same case can pass and fail with no change in between.** Repeat a failing case before acting, and use `npm run regrade` to check a changed assertion or rubric against stored replies, which also shows whether a change just made it looser.
- **Prose is graded by a model, and a grader can be stricter or looser from one call to the next.** Read the grader's reason before reading a failure as the agent's. Two rubric faults found so far were a rubric that wanted a literal phrase, and one that couldn't tell building before approval from building after it.
- **Behaviour failures that led to text changes:** `developer` described the build and carried on instead of ending at the design; `product-analyst` designed the solution itself; `quality-engineer` offered to fix production code; `adr` didn't say when the old ADR becomes Superseded. These are in the plugin changelog. Rules stated in several places didn't hold better than one clear statement, so prefer one clear statement in the Role section.
- **Models.** Haiku models and several others rarely call the `skill` tool unprompted, so evals pin `gpt-6-luna`. Higher reasoning effort didn't fix that.
- **Stopping a run early** was tried and dropped: runs go to their natural end, so the usage file is always written. On Windows a plain kill leaves child processes behind, so the provider ends the whole process tree on a time-out.

## Not done yet

- **Delegation.** Whether `developer` delegates only bounded mechanical work to `developer-worker`, and the `subagents` evidence, are untested. Cases start the worker directly.
- **Linux and macOS.** Only Windows has been run. The provider's Linux and macOS code is covered by unit tests with fakes, and the tool names there are unchecked.
- **A worker model matrix.** Run the `developer-worker` cases against every model in the allow-list in `lint.config.json` at each release review.
- **Trend tracking** of pass rates and cost over time.
- **Writing cases.** Behaviour cases that say "never change X" (B-QE-3, B-PA-2) are read-only, so they grade what the agent says it would change. If one keeps flipping, let it write to the temporary copy and assert on the files.
- **Evals in CI.** Use a separate workflow on a manual trigger and a schedule, never on `pull_request`, because secrets aren't available to pull requests from forks. It needs answers to who funds the credits, whose token is the repository secret, and how to install a pinned Copilot CLI on a runner. The rubric grader can already be replaced with `--grader <provider>`, for example a Microsoft Foundry endpoint. The agents themselves still run on Copilot CLI.

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
| `cases/behaviour/<agent>.yaml` | The behaviour cases, one file per agent                           |
| `fixtures/consumer-repo/`      | The stand-in consumer repository, in the neutral domain           |
| `fixtures/overlays/<name>/`    | Files copied over the fixture, uncommitted, for one case          |
| `promptfooconfig.routing.yaml` | The routing suite's config                                        |
| `promptfooconfig.behaviour.yaml` | The behaviour suite's config                                    |
| `scripts/eval.js`              | The run command                                                   |
| `scripts/regrade.js`           | Grades stored replies again, with no agent run                    |
