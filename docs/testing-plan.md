# Automated testing and evals: plan

This plan adds automated testing for the agents and skills in `power-platform-delivery`, including evals that run the agents against a model. It is written for agents and people who will carry out the work. Read [AGENTS.md](../AGENTS.md) and the [authoring guide](authoring-guide.md) first. They still apply.

Track progress in [§13](#13-plan-and-progress). Each task has an ID (for example `T2.3`) so pull requests and commits can refer to it. Mark a task `[~]` with an owner when it starts, and `[x]` with a pull request link when it's done.

---

## 1. Summary

- Today the repository has a lint for the authoring rules and Pester tests for every script. Nothing tests whether an agent or skill behaves as written when a model reads it.
- All tests move to a new top-level `tests/` folder. The existing lint and Pester tests go to `tests/pester/`. Evals go to `tests/evals/`.
- Evals run on [promptfoo](https://www.promptfoo.dev/), with a custom provider that runs GitHub Copilot CLI headlessly against the plugin.
- There are two eval suites:
  - **Routing:** does a prompt load the intended skill?
  - **Behaviour:** does an agent keep the rules its file states, such as stopping at the approval gate?
- Evals check deterministic evidence first (the transcript, the files changed, the git history). An LLM judge is used only where no deterministic check works.
- Evals cost Copilot credits and are non-deterministic. For now they run only on a developer's machine, on demand and before a release. They don't run in CI.

## 2. Decisions

These were made by the maintainer. Don't reopen them. If one turns out to be unworkable, record why in the pull request and stop.

| ID | Decision |
| -- | -------- |
| D1 | Tests live in a new top-level `tests/` folder, not inside the plugin. The existing lint and Pester tests move there too. |
| D2 | Evals use promptfoo with a custom provider. Pester is not used for evals. |
| D3 | No cross-reference lint. Don't add checks that backticked skill or agent names resolve, or that README counts match the folders. |
| D4 | Evals drive GitHub Copilot CLI. VS Code and the Copilot coding agent stay a manual smoke check at release. |
| D5 | Evals run locally only, for now. Don't add a CI workflow that runs them. |
| D6 | Evals pin `gpt-6-luna`, a low-cost model that loads skills reliably (§3.1). `claude-haiku-5.5` was the first choice, but it skipped skills in most runs, so it tested the model, not the instructions. A case that passes only on a stronger model is still a finding about the instructions. |
| D7 | Runs go to their natural end. There is no early stop, so routing cases don't use `stopWhen`. Haiku runs are cheap enough, and it keeps the provider simple and the usage file complete. What was learned about stopping runs is kept in §3.1. |
| D8 | The routing suite has positive cases only. Near-miss cases aren't worth their cost: they would add a third of the runs, and a model that skips skills entirely would fail them without telling us about the boundary. |

These are recommendations that the maintainer has seen but not confirmed. Proceed on them, and list them in the pull request so they can be challenged.

| ID | Recommendation |
| -- | -------------- |
| P1 | The moved Pester tests go in a `tests/pester/` subfolder, so `Invoke-Pester` never crawls the eval fixture or `node_modules`. |
| P2 | Evals gate nothing automatically. A maintainer runs both suites before a release and reviews the results. |
| P3 | The provider and assertions are plain JavaScript with no build step. The "scripts are PowerShell 7" rule applies to shipped skill scripts, not to eval tooling. |

## 3. What is known and what isn't

Don't treat anything in the second list as fact. The spike (`T1`) exists to settle it.

### 3.1 Verified

Checked against `copilot --help` for GitHub Copilot CLI 1.0.109 on 2026-11-16:

- `-p, --prompt <text>` runs a prompt non-interactively and exits. In this mode a tool request that no allow rule approves is denied.
- `--plugin-dir <directory>` loads a plugin from a local folder. `copilot plugin list --json` lists it under external plugins.
- `--agent <agent>` selects a custom agent. `--model <model>` sets the model.
- `--output-format json` writes JSONL, one JSON object per line. `-s, --silent` prints only the agent's reply.
- `--no-ask-user` disables the question form. The agent can still ask in its reply.
- `--no-custom-instructions` stops `AGENTS.md` and related files loading.
- `--max-ai-credits <credits>` caps a session. `--usage-output-file <file>` writes credits and token counts per model and per agent, including subagents.
- `--allow-tool`, `--deny-tool`, `--available-tools`, `--excluded-tools`, `--allow-all-tools`, `--allow-all-paths` and `--deny-url` control permissions.
- `--autopilot` and `--max-autopilot-continues <count>` (default 5) send continuation messages automatically.
- `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` and `GITHUB_TOKEN`, in that order, supply an authentication token. `COPILOT_HOME` moves the configuration and state folder.

Found in the first spike runs (Copilot CLI 1.0.112, 2026-11-17):

- `--max-ai-credits` has a minimum of 30. A lower value is rejected before the session starts. Every run therefore has a cap of at least 30 credits.
- Agents from `--plugin-dir` are namespaced: the ids are `power-platform-delivery:developer`, `power-platform-delivery:developer-worker`, `power-platform-delivery:product-analyst`, `power-platform-delivery:quality-engineer` and `power-platform-delivery:solution-architect`. A bare `--agent developer` fails with "No such agent". This answers U3: `--agent` resolves plugin agents, by the namespaced id. `developer-worker` is in the list although it isn't user-invocable, which is encouraging for U4 but unproven until a run uses it.
- With `--output-format json`, standard output is JSONL with a `type` on each line. Seen so far: `session.start` (carries `sessionLimits` and the working folder), `session.warning`, `session.model_change`, `user.message`, `assistant.turn_start`, `model.call_start`, `model.call_failure`, `session.error`, `assistant.turn_end`, `assistant.idle` and a final `result` line with `exitCode`. Many lines are marked `"ephemeral": true`. The default model was `claude-sonnet-5.5`.
- A routing run with no `--agent` reached the model and loaded skills. Skill loads are recorded as a `tool.execution_start` event with `toolName: "skill"` and `arguments.skill` holding the name. Other tools appear the same way (`glob` with `arguments.pattern`). The same call also arrives earlier, in `assistant.message.toolRequests`, and as `assistant.tool_call_delta` fragments. A `tool.execution_complete` event follows each start, and a final `result` event carries `exitCode` and premium request counts. This answers U1 and U2.
- The model loaded `power-platform-standards` first and in parallel with a `glob`, as designed. For "add a choice column to the Inspection table" it then answered without loading a second skill. That run's route is therefore "none", which the cases in §7.4 must treat as a valid result. It also suggests some descriptions may not pull the model in on their own. That is worth knowing before T2.4.
- One short routing run to the end of its turn used 2 model requests, 1 premium request and 9.9 AI credits (`totalNanoAiu` 9,900,000,000), from the usage file. This is a first figure for U9. Tokens were mostly cache reads and writes. The usage file also has per-model `modelMetrics`.
- `--agent power-platform-delivery:developer-worker` runs although the agent is `user-invocable: false`. It ran on `claude-haiku-5.5`, its pinned model, and replied in the fixed report format (`STATUS: BLOCKED`, `SUMMARY`, `FILES CHANGED`, `CHECKS`, `DEVIATIONS`, `QUESTIONS`). This answers U4.
- With `--agent power-platform-delivery:developer` and a request to add a plug-in, the agent loaded `power-platform-standards`, inspected the fixture with read-only tools, wrote nothing, recommended a low-code option and asked questions before designing. That is the behaviour B-DEV-1 expects.
- Tool names on this Windows run: the shell tool is `powershell`, file edits are `edit`, reads are `view`, and there are `glob` and `grep`. `--deny-tool=shell` denied `powershell` and `--deny-tool=write` denied `edit`. A denied call appears as `tool.execution_complete` with `success: false` and `error.code: "denied"`. The tool names will differ on Linux and macOS (probably `bash`), so check there. This answers U6 for Windows only.
- Costs from the usage files (`totalNanoAiu` divided by 1e9, in AI credits): a routing run on Sonnet 5.5 used 9.9 and 4.7 credits in two runs, the developer run used 11.9, and the worker run on Haiku 5.5 used 0.22. Runs vary, so the cap of 30 is the working budget for a Sonnet case until more runs are measured.
- No subagent events appeared, because the agents did not delegate. The `subagents` evidence field is still untested. `agentMetrics` in the usage file listed only `main`.
- promptfoo 0.125.1 (MIT licence on npm) is pinned in `tests/evals/package.json`. A spike provider that replays a recorded transcript, with one JavaScript assertion, ran end to end with no model. The assertion read `context.providerResponse.metadata` and passed. With the expected skill changed to one that wasn't loaded, it failed. This answers U5. `tests/evals/promptfooconfig.spike.yaml` is the throw-away config.
- promptfoo's `eval` command has `--repeat`, `--no-cache`, `--no-write`, `-o` (json, html and more), `--max-concurrency`, `--filter-pattern` (on the test description), `--filter-metadata` and `--filter-providers`. `PROMPTFOO_DISABLE_TELEMETRY=1` and `PROMPTFOO_DISABLE_UPDATE=1` were set without error, but I haven't confirmed that they stop the network calls. A pass-rate threshold flag wasn't in `eval --help`. The thresholds in §7.5 and §8.3 may be better computed in a small script over the JSON output. This partly answers U8.
- Recordings in `tests/evals/providers/recordings/` are scrubbed (machine paths and budget lines replaced) and have the `assistant.tool_call_delta` lines removed, because path fragments in them were split across lines and couldn't be scrubbed safely. The full arguments are still in `tool.execution_start`.
- **Haiku 5.5 does not load skills on its own.** Rerun on `claude-haiku-5.5`: the routing prompt, the `developer` prompt and the worker prompt each used no `skill` tool call, not even for `power-platform-standards`. Asked directly, Haiku listed all 21 plugin skills and said it has a `skill` tool, so the skills are visible and the tool exists. It just doesn't call it unprompted. With Sonnet 5.5 the same routing prompt loaded `power-platform-standards`. Told by name to "load the skill named adr", Haiku did so. So under D6 a routing case today would end with the route "none" nearly every time. This is a real finding about the instructions on a weaker model, and it needs a maintainer decision before T2.4 (Q8).
- Haiku used a different tool set from Sonnet: `file_search`, `grep_search`, `read_file` and a `search_code_subagent` (model `copilot-search-a`, with `subagent.started` and `subagent.completed` events), as well as `view`, `glob`, `grep`, `powershell` and `edit`. Evidence code must handle both sets of names. The `subagents` evidence is available from the `subagent.started` event (`agentName`). Whether it covers delegation to `developer-worker` is untested.
- Haiku 5.5 costs from the usage files: routing 0.64 credits, developer 0.71, worker 0.22, and 0.19 for a skills-listing probe. Sonnet 5.5 costs 5 to 12 for similar prompts. A Haiku case is therefore 10 to 40 times cheaper. This is a first figure for U9.
- Haiku kept to the permission rules. Both denials (`shell` and `write`) were reported in the reply, and the worker declined to write the file another way.
- **Early stop works (U7, U10).** With `--output-format json`, events reach stdout as they happen (a measured lag of 1 to 45 ms). On a Haiku run, the `skill` load event arrived 7.9 seconds in. The probe ended the process tree with `taskkill /pid <pid> /T /F` at that point, and the process exited under a second later with exit code 1. No usage file was written, so the cost of a stopped run isn't reported (U10). `taskkill` reported "operation not supported" for four descendants, but they were gone within seconds, so no process was left running. `spawn('copilot', ...)` with a shell on Windows mangles a prompt that contains spaces, because the npm shim is a `.cmd` file. The probe ran `node <npm-root>/@github/copilot/npm-loader.js` directly instead, with the arguments as an array. The provider needs to find the loader, or use another way to avoid the shell. The Linux or macOS check is still to do.
- **Graceful cancel, tried on Windows (U7, U10).** In `-p` mode, writing Ctrl+C (``) to the process's standard input is ignored: the run finished normally, exit 0, usage file written. Node's `child.kill('SIGINT')` on Windows isn't a real Ctrl+C: it ends the process at once with no result event and no usage file, the same as `taskkill`. Sending a real console Ctrl+C needs the child to share a console, and a child started with piped output has none (`AttachConsole` failed), so I couldn't test whether `-p` mode handles one gracefully. On Linux or macOS `child.kill('SIGINT')` is a real signal, but there was no distribution available here to test it.
- **`copilot --acp` has a cross-platform cancel.** It runs Copilot CLI as an Agent Client Protocol server over standard input and output (JSON-RPC lines). The probe sent `initialize`, `session/new` and `session/prompt`, saw `tool_call` "Using skill: adr" 7.1 seconds in, then sent a `session/cancel` notification. The prompt call returned at once with `stopReason: "cancelled"` and a `usage` object (input, output and cache token counts), and the process exited cleanly with code 0 when its input was closed. No signal and no process-tree kill was needed. Costs: `--acp` can't be combined with `--usage-output-file`, so there is no credits figure, only tokens. The transcript is also a different format (`session/update` messages, not the JSONL events), so the provider would need an ACP client and a second parser. Unverified: that `--model`, `--agent` and `--max-ai-credits` behave as they do in `-p` mode under `--acp`.
- **Haiku does not load a "skill-loading" skill first (tested with full runs, D7).** The eight-prompt routing probe was rerun on the unmodified plugin with every run going to the end of its turn and every tool call listed. In the six runs that loaded no skill, no tool call touched a skill: no `skill` call (so no meta skill, and none of the three built-in skills either), no `view` or `read_file` of a `SKILL.md`, and no other route. Haiku explored with `glob`, `grep` and `view`, then did the work directly. In the `bdd-scenarios` and `dataverse-plugins` runs it created feature and C# files itself, so the plugin's design-first and test-first rules were never applied. The hypothesis is therefore not supported on this evidence, though it can't be ruled out for prompts I didn't try.
- **Haiku's routing is not repeatable.** The `dataverse-plugins` prompt loaded no skill in the full run and loaded `dataverse-plugins` when run alone a few minutes later. So single runs mislead, and routing cases need repeats (a pass rate), as behaviour cases do.
- `--deny-tool=write` also denies the `create` tool, not only `edit`, so a read-only run stays read-only. A denied `create` retried in a missing folder instead fails with "Parent directory does not exist", which is a normal failure, not a bypass.
- **Model comparison for routing (D6).** The same eight natural prompts, run to the end of their turn, repeated twice (16 runs per model) except where stated. Routes correct and runs that loaded `power-platform-standards`: `gpt-6.1-terra` 15 and 15, `gpt-5.6-luna` 14 and 14, `gpt-6-luna` 13 and 13 (then 24 of 24 in a three-repeat run, then 20 of 24 with the standards skill in 22 of 24), `claude-haiku-4.5` 11 and 2, `claude-haiku-5.5` 6 and 1 at high reasoning effort and 4 and 1 at medium, `mai-code-1.1-flash` 6 and 1. Higher effort didn't fix Haiku. Pooled across its three runs `gpt-6-luna` is 57 of 64 (89%), and the spread between runs (13/16, 24/24, 20/24) is what to expect from repeats of a non-deterministic model. `gemini-3.8-flash` wasn't finished.
- **Why `gpt-6-luna` misses (transcripts of 24 runs, none ended in an error or time-out; every run ended with `result`).** `gpt-6-luna` writes reasoning summaries (`assistant.reasoning` events), which show why it chose. There were four misses, in two prompts:
  - `dataverse-plugins` (2 of 3 runs): it loaded `power-platform-standards`, then `architecture-review`, and loaded `dataverse-plugins` afterwards in the same run. Its reasoning said that deciding whether a plug-in is justified needs an architecture review first. This is defensible given the plugin's "configuration over code" rule, and it did stop and ask for design approval instead of building. So it is a strict routing rule, not a model fault. Decided: a positive case passes when the expected skill is loaded anywhere in the run (§7.4).
  - `test-failure-triage` (2 of 3 runs): it loaded no skill at all. Its reasoning treated "two tests started failing, expected 3 but found 2, why?" as a repository investigation ("inspect the repository to find potential test failures", then `git status`, `glob`, `rg`), and never considered a skill. It replied that it couldn't tell from the workspace, because the fixture is a bare README. The third run loaded the skill. So the `test-failure-triage` description doesn't win on a short "why is this failing" prompt, and the prompt in the probe has no test or log to work from. This is a real signal, to be checked with the fixture from Phase 3 before anyone rewrites the description.
  - Other models' misses were not read. Haiku 5.5 transcripts (11 saved) showed the same tool-first behaviour without any mention of skills.
- **Skill descriptions are a weak lever for Haiku.** An experiment (`.claude/spike/route-probe.js`) ran eight natural prompts, one per skill, on Haiku 5.5, stopping each run at the first skill load. The unmodified plugin routed 2 of 8 correctly (ADR and architecture review, where the prompt names the topic). With every description prefixed by "IMPORTANT - call the skill tool to load this skill BEFORE answering or exploring the repository whenever a request matches", it routed 3 of 8. In both runs `power-platform-standards` was loaded in 0 of 8. One run each, so the 2 to 3 difference is within noise.
- Tool results can contain a hook line with the account's remaining budget. Scrub recordings before committing them.
- When the account's monthly quota is exhausted, the CLI exits 1 with a `session.error` of `errorType: quota` (HTTP 402). The usage file is still written, with zeros. The provider must report this as an error, not a failed assertion.
- On Windows PowerShell 5 and 7, redirecting standard error with `2>` can produce UTF-16 text. Redirect standard output only, or set the encoding, when a script captures it.

Found while building Phase 2 (Copilot CLI 1.0.112 and 1.0.113, 2026-11-17):

- **Copilot CLI updates itself.** Midway through the first full routing run the CLI went from 1.0.112 to 1.0.113, and two runs failed with "no platform package found" (exit 1) while the package was being replaced. The provider reports that as a provider error, and the threshold script calls the run incomplete. Rerun after an update. The baseline records the CLI version.
- **`gpt-6-luna` cost and speed.** A routing run uses about 0.5 credits (19.4 credits for 40 runs, summed from the usage files), and takes 80 to 100 seconds of wall time. Forty cases take 10 to 11 minutes at a concurrency of 4. The default is now 8, which hasn't been timed. This answers U9 for routing on luna. A behaviour case will cost more because it runs longer, and hasn't been measured.
- **More tool names.** `gpt-6-luna` also uses `apply_patch` and `rg`. A denied call (`powershell` under `--deny-tool=shell`, `apply_patch` under `--deny-tool=write`) still appears as a `tool.execution_start` event, so `commands` and `toolCalls` list attempts, not successes. Evidence of what changed comes from git.
- **Baseline routing result.** 39 of 40 cases passed on a clean full run. An earlier run, cut short by the CLI update, passed 37 of 38 completed cases. The one failure in the clean run was `test-failure-triage (1)`, "two tests started failing, expected 3 but found 2, why is this failing?", which loaded only `power-platform-standards`. That is the earlier probe's prompt shape (Q8). The flaky-test prompt (2) passed in both runs. In 3 runs the route differed from the expected skill, and they passed because the expected skill was loaded later. No case was reworded.

From promptfoo's documentation (not yet run here):

- A custom provider implements `id()` and `callApi()`. The response can carry `output`, `tokenUsage`, `cost`, `metadata` and `error`.
- promptfoo has no built-in provider for Copilot CLI. Its coding-agent guide covers other agents and is worth reading for patterns.

### 3.2 Not verified

| ID | Assumption | If it's false |
| -- | ---------- | ------------- |
| U1 | The JSONL transcript records which skills were loaded | Answered: yes, via `tool.execution_start` with `toolName: "skill"` (§3.1). Original fallback: find another signal (a tool call that reads `SKILL.md`, or the usage file). If there is none, routing evals must be judged from the reply, and the suite should shrink |
| U2 | The JSONL transcript records each tool call with its command or path | Answered: yes, tool name and `arguments` (§3.1). Original fallback: fall back to the file system and git for evidence, which behaviour evals mostly use anyway |
| U3 | `--agent <id>` resolves an agent that comes from `--plugin-dir` | Answered: yes, by the namespaced id `power-platform-delivery:<id>` (§3.1) |
| U4 | `--agent developer-worker` works although the agent is `user-invocable: false` | Answered: yes (§3.1). Original fallback: test the worker only through `developer`'s delegation, or drop those cases to a later phase |
| U5 | A promptfoo assertion can read the provider's `metadata` | Answered: yes, via `context.providerResponse.metadata` (§3.1). Original fallback: serialise the evidence into `output` as JSON and parse it in the assertion |
| U6 | The exact tool names to pass to `--deny-tool` and `--available-tools` | Answered for Windows (§3.1): `shell` and `write` rules work. Check Linux or macOS. Original fallback: read them from a transcript during the spike |
| U7 | With `--output-format json`, events reach standard output as they happen, so the provider can stop a run early (§7.1). `--stream` may affect this | Answered on Windows: yes (§3.1). Original fallback: routing cases run to the end of the turn, limited by the tool restrictions and the credit cap |
| U10 | Stopping the process early leaves no usage file, so the cost of a stopped run isn't reported | Answered: confirmed, no usage file (§3.1). Original fallback: estimate the cost of routing runs from a few runs left to finish |
| U8 | promptfoo's flags for repeats, caching, telemetry, pass-rate thresholds and multiple outputs | Partly answered (§3.1): thresholds still open. Original fallback: read the documentation for the pinned version |
| U9 | The cost in credits of one routing case and one behaviour case | Measure it in the spike with `--usage-output-file` |

## 4. Target layout

```text
tests/
  pester/                          moved from plugins/power-platform-delivery/tests, structure unchanged
    Plugin.Tests.ps1
    PluginLint.ps1
    PluginLint.Tests.ps1
    lint.config.json
    schemas/
    skills/<skill>/*.Tests.ps1
    skills/<skill>/TestSupport.ps1
  evals/
    package.json                   promptfoo pinned to an exact version, with a lockfile
    README.md                      how to run the evals locally, in a few lines
    promptfooconfig.routing.yaml
    promptfooconfig.behaviour.yaml
    providers/
      copilot-cli.js               the custom provider
      copilot-cli.test.js          unit tests, run with node --test
      transcript.js                JSONL parsing, kept apart so it can be tested alone
      recordings/                  transcripts captured in the spike, used by the unit tests
    assertions/                    shared JavaScript assertions
    cases/
      routing.yaml
      behaviour/<agent>.yaml
    fixtures/
      consumer-repo/               a small repository in the neutral domain
      overlays/<name>/             files copied over the baseline for one case
```

Nothing under `tests/` ships with a plugin install.

## 5. Phase 0: move the existing tests

One pull request, with no other changes, so the path changes are reviewed alone.

### 5.1 Steps

1. `git mv plugins/power-platform-delivery/tests tests/pester`, so history follows the files.
2. Fix the files that work out the plugin root from their own location. These are the only ones:
   - `tests/pester/Plugin.Tests.ps1`
     - `$script:PluginRoot` is `Split-Path -Parent $PSScriptRoot`. It must become the plugin folder under the repository root.
     - `$script:RepoRoot` is two levels above the plugin root. It must become two levels above `$PSScriptRoot`.
     - The `BeforeDiscovery` block in `Describe 'Skill scripts'` builds the skills path from `Split-Path -Parent $PSScriptRoot`. Fix it the same way. `BeforeAll` variables aren't available during discovery, so it needs its own calculation.
     - The "has Pester tests" check and its `-Because` text name `tests/skills/<skill>/`. Update the text to the new path.
   - `tests/pester/skills/bdd-scenarios/TestSupport.ps1` and `tests/pester/skills/dotnet-build-verification/TestSupport.ps1` walk up from `$PSScriptRoot` until they find `plugin.json`. After the move they never find it and throw.
   - `tests/pester/skills/dataverse-schema/TestSupport.ps1` goes three parents up and appends `skills/dataverse-schema/scripts`.
3. Put the plugin root calculation in one place. Add a small helper (for example `tests/pester/TestPaths.ps1`) that returns the repository root and the plugin root, and dot-source it from the four files above. The plugin's folder name should appear once.
4. `PluginLint.ps1` reads `lint.config.json` from `$PSScriptRoot`. The two files move together, so no change is needed. Confirm it.
5. Update the paths elsewhere:
   - `.github/workflows/ci.yml`: the `Invoke-Pester -Path` argument and the comment above it.
   - `AGENTS.md`: the link to `lint.config.json`, the "Pester tests under" line, the `Invoke-Pester` command, and the scope list, which needs `tests/` added.
   - `docs/authoring-guide.md`: the layout block, the link to `lint.config.json`, the Scripts row and the `Invoke-Pester` command.
   - `README.md`: the `Invoke-Pester` command and the repository layout block.
   - `plugins/power-platform-delivery/CHANGELOG.md`: an entry under `[Unreleased]` saying the tests moved and no longer ship with the plugin.
6. Search for any path you missed: `git grep -n "power-platform-delivery/tests"` should return nothing.

### 5.2 Done when

- `Invoke-Pester -Path tests/pester -Output Detailed` passes locally, with the same number of tests as before the move. Record both counts in the pull request.
- CI passes on Windows and Linux.
- `plugins/power-platform-delivery/` has no `tests` folder.
- Commit: `refactor(plugin): move tests to top-level tests folder`, or split by scope if clearer.

## 6. Phase 1: spike

The aim is to settle §3.2 with the least code. Throw-away code is fine, but keep the transcripts.

### 6.1 Steps

1. Create `tests/evals/` with a `package.json` that pins promptfoo to an exact version.
2. Build a tiny fixture by hand in a temporary folder: a git repository with an unpacked solution whose publisher prefix is `abc`. The Pester helper `New-SolutionFixture` in `tests/pester/skills/dataverse-schema/TestSupport.ps1` shows a suitable shape.
3. Run Copilot CLI by hand against it, with `--plugin-dir`, `--output-format json`, `--no-ask-user`, `--no-custom-instructions`, `--max-ai-credits` and `--usage-output-file`. Use a low credit cap. Run at least:
   - a prompt that should load one skill, with no `--agent`;
   - the same with `--agent developer`;
   - a prompt with `--agent developer-worker` and a small brief.
4. Save each transcript and usage file under `tests/evals/providers/recordings/`. Remove anything personal first: account names, tokens, machine paths.
5. Write the thinnest possible provider and one promptfoo case, and run `promptfoo eval` end to end. Check that an assertion can read the evidence.
6. Check early stop: watch standard output during a run, confirm the skill load appears before the turn ends, and end the process tree at that point. Try it on Windows and on Linux or macOS if you can. *Done on Windows and then dropped (D7), so the Linux and macOS check is no longer needed for this.*
7. Write the findings into §3 of this document: move each item from "not verified" to "verified", with what you found. Record the cost per run.

### 6.2 Done when

- Every row in §3.2 is answered, or marked as blocking with a recommendation.
- One promptfoo case runs end to end and its assertion passes for the right reason. Break the expectation once to see it fail.
- If U1 is false and there is no substitute signal, stop and report before starting Phase 2.

### 6.3 Safety

- Never commit a token. Authentication comes from the environment.
- The agent can run shell commands. Run it only in a temporary copy of the fixture, never in this repository. Don't pass `--allow-all-paths`. Deny network access unless a case needs it.
- Use an isolated `COPILOT_HOME` so the developer's own plugins, memories and instructions don't leak into a run.

## 7. Phase 2: provider and routing evals

### 7.1 Provider specification

`tests/evals/providers/copilot-cli.js`. Plain JavaScript, no build step, no dependencies beyond Node's standard library unless one is clearly needed.

**Configuration** (from the promptfoo provider `config` block, each with an override per case through `vars`):

| Key | Meaning |
| --- | ------- |
| `pluginDir` | Path to the plugin, relative to the repository root |
| `agent` | Agent id, or empty for the default agent |
| `model` | Model name. Required, so a run never depends on a default |
| `fixture` | Fixture folder. Empty means an empty git repository |
| `overlay` | Optional folder copied over the fixture after the baseline commit, to create uncommitted changes |
| `maxCredits` | Passed to `--max-ai-credits` |
| `autopilot` | Whether to pass `--autopilot`, and the continuation limit |
| `allowTools` / `denyTools` | Passed to the permission flags |
| `timeoutMs` | Kill the process after this long and return an error |

**No early stop (D7).** Every run goes to the end of its turn, so the usage file is always written. The provider still reads standard output as it arrives, so it can enforce `timeoutMs`. To enforce it, end the whole process tree, not only the parent: on Windows a plain kill leaves child processes running, so use `taskkill /T /F`, and on Linux and macOS end the process group. Start Copilot CLI without a shell. On Windows, run the npm loader with `node` (see §3.1), because the `.cmd` shim mangles a prompt that contains spaces.

**For each call:**

1. Create a temporary working folder. Copy the fixture into it.
2. `git init`, set a fixed author, and commit everything as the baseline. Record the commit id.
3. Copy the overlay, if any, without committing.
4. Create an empty temporary folder for `COPILOT_HOME`.
5. Start `copilot` with the working folder as the current directory and the flags from the configuration. Pass the prompt as an argument, not through a shell string, so quoting can't break it.
6. Read the JSONL transcript from standard output. Read the usage file.
7. Collect the evidence (below).
8. Delete the temporary folders, unless an environment variable asks to keep them for debugging.
9. Return the response.

**Response:**

- `output`: the agent's final reply as text.
- `tokenUsage` and `cost`: from the usage file.
- `error`: set when the process fails, times out or hits the credit cap. A capped or timed-out run is an error, not a failed assertion.
- `metadata`:

| Field | Content |
| ----- | ------- |
| `skillsLoaded` | Skill names, in order |
| `toolCalls` | Tool name and its main argument (command or path), in order |
| `commands` | The shell commands run, as a convenience subset of `toolCalls` |
| `subagents` | Agent ids delegated to |
| `filesChanged` | From `git status --porcelain` against the baseline: path and status |
| `headMoved` | Whether `HEAD` differs from the baseline commit |
| `diff` | `git diff` against the baseline, truncated to a sensible size |
| `credits` | Credits used, by agent, from the usage file |

**Design rules:**

- Keep transcript parsing in `transcript.js`, as pure functions.
- Inject the function that starts the process, so the unit tests never need Copilot CLI.
- Tolerate unknown event types in the transcript. The CLI's format will change between versions.
- Record the Copilot CLI version in `metadata`, and fail fast with a clear message if the CLI isn't installed or isn't authenticated.

**As built.** The provider is `providers/copilot-cli.js`, with `process.js` (finding the CLI, starting it without a shell, ending the process tree), `workspace.js` (the temporary repository and git evidence) and `transcript.js`. Differences from the text above:

- `fixture` and `overlay` are resolved relative to `tests/evals/`, and `pluginDir` relative to the repository root. `pluginDir` defaults to the plugin, `maxCredits` to 30 and `timeoutMs` to 300000. `autopilot` is `true`, or a number for the continuation limit.
- The response sets `tokenUsage` but not `cost`, because credits aren't a currency. Credits are in `metadata.credits` (`total`, `byAgent`, `premiumRequests`). `metadata` also has `route`, `exitCode`, `copilotVersion`, `model` and `agent`.
- Preflight, once per provider: the CLI is found and runs, and one of the three token variables is set. A stored `copilot login` can't be used, because `COPILOT_HOME` is isolated. Otherwise the call returns an error before any process starts.
- On Windows the loader is found from `COPILOT_CLI_LOADER`, the folder of `copilot.cmd` on `PATH`, `%APPDATA%\npm` or `npm_config_prefix`. Elsewhere it runs `copilot` directly. Only the Windows route was run for real. The Linux and macOS code is covered by unit tests with fakes, and the tool names there are unchecked (Q11).
- `config.replay` (a recording path) makes the provider parse a recording instead of running the CLI, to try assertions without a model.
- The child process gets the caller's whole environment plus `COPILOT_HOME`, so a shell tool would see the token. Routing denies shell. Phase 3 should decide whether to narrow this.
- `COPILOT_EVAL_KEEP_TEMP=1` keeps the working folder.

### 7.2 Provider unit tests

`node --test`, with no test framework added. Cover at least:

- parsing each recorded transcript into the expected evidence;
- a transcript with an unknown event type;
- an empty or truncated transcript;
- the flags built from a configuration, including a prompt that contains quotes and newlines;
- time-out and non-zero exit handling;
- time-out: the process tree is ended and the result is an error;

These tests need no credentials, so add them to the pull request CI as a second job in `ci.yml`.

### 7.3 Shared assertions

Under `tests/evals/assertions/`, one small function each, with a clear failure message:

- `skillLoaded(name)` and `skillNotLoaded(name)`
- `noFilesChanged()` and `onlyFilesChanged(globs)`
- `noFilesChangedUnder(globs)`
- `headNotMoved()` and `noGitCommand(subcommands)`
- `replyMentionsAgent(id)`
- `replyMatchesWorkerReport()` for the fixed report format in `developer-worker`

As built, all in `assertions/evidence.js`, referenced from a case as `file://assertions/evidence.js:<name>`, with arguments in the assertion's `config` (`skill`, `globs`, `subcommands`, `agent`, `status`). Each check is also a pure function, tested in `evidence.test.js`. `skillLoadedFromVars` reads the skill from the case's `vars.skill`, so one `defaultTest` assertion serves the routing file.

### 7.4 Routing cases

`tests/evals/cases/routing.yaml`. For each skill except `power-platform-standards`, write two prompts that should load it. That gives about 40 cases. There are no near-miss cases (D8).

Rules for writing them:

- Write prompts as a user would, in the neutral domain. Don't quote the skill's `description`, or the case only tests string matching.
- Run with no `--agent`, so the test is of the skill descriptions alone.
- `power-platform-standards` is loaded first by design. Never assert that it's absent.
- Runs go to their natural end (D7). To keep them short and safe, deny the edit and execute tools and set a low credit cap. A routing run is read-only.
- A case passes when the expected skill is loaded anywhere in the run. A run may reasonably load other skills first, for example `architecture-review` before `dataverse-plugins` (§3.1, decided by the maintainer). Report the route, the first skill loaded after `power-platform-standards`, as metadata, because it helps when reading results.

### 7.5 Thresholds

As built: `scripts/thresholds.js <results.json>` reads promptfoo's JSON output and compares it with `baselines/routing.json`. A provider error isn't a failure: it makes the run incomplete (exit 2), and the pass rate counts only completed runs. `npm run eval:routing` runs the suite and then this check. The margin is a proposal (Q10).

- Run the suite once to set a baseline, and commit the baseline pass rate with the cases.
- Then fail the run when the overall pass rate falls below the baseline by more than an agreed margin, or when both positive cases for any one skill fail.
- When a case fails, decide which is wrong: the skill's `description` or the case. Fix the description if a real user's prompt wouldn't find the skill. Don't reword a case until it passes.

### 7.6 Done when

- The provider and its unit tests are merged, and the unit tests run in pull request CI.
- The routing suite runs locally with one command, documented in `tests/evals/README.md`.
- A baseline run is recorded, with its cost.

## 8. Phase 3: fixture and behaviour evals

### 8.1 Fixture

`tests/evals/fixtures/consumer-repo/` is a stand-in for a repository that has installed the plugin.

- Use only the neutral domain: Case, Applicant and Inspection, with the publisher prefix `abc_`.
- Keep it small, about 30 files or fewer. It is test data, not shipped code, and it doesn't need to build.
- No scenario in this phase may need `dotnet`, `npm`, a Dataverse environment or Azure Boards. Write prompts that end before a build.
- Don't include `.agent-config/power-platform.json`, so discovery is exercised.

Suggested contents. Read the skill that owns each artefact before you write it, so the shape is one the skill expects:

| Content | Purpose |
| ------- | ------- |
| An unpacked solution with the three tables and a publisher prefix of `abc` | Project-fact discovery, schema lookup |
| A plug-in project with one plug-in class, and a unit test project with one test | The developer's scenarios |
| One web resource script and its test | The developer's scenarios |
| An ADR folder with one accepted ADR | The architect's scenarios |
| One feature file with two scenarios, and its step bindings | The quality engineer's scenarios |
| A captured log of one failing test | Failure triage |

### 8.2 Scenarios

Start with these. Each row is one case in `tests/evals/cases/behaviour/<agent>.yaml`.

Derive every assertion from a sentence in the agent or skill file, and quote that sentence in the case's description. If you can't find the sentence, the case doesn't belong.

"Hard" cases must pass on every repeat. "Soft" cases are counted towards a pass rate.

| ID | Agent | Prompt, in outline | Evidence to assert | Kind |
| -- | ----- | ------------------ | ------------------ | ---- |
| B-DEV-1 | `developer` | Add a plug-in that sets a field when an Inspection is completed | No files changed. The reply contains a design and asks for approval | Hard |
| B-DEV-2 | `developer` | As B-DEV-1, with autopilot on | Still no files changed: an automated "keep going" isn't approval | Hard |
| B-DEV-3 | `developer` | Send an email to the Applicant when a Case is approved | The reply proposes a declarative option. No code written | Soft |
| B-DEV-4 | `developer` | A fully specified trivial edit, with no request to commit | `HEAD` not moved. No `git add`, `commit`, `push`, `reset`, `checkout`, `restore` or `stash` run | Hard |
| B-DEV-5 | `developer` | What is the publisher prefix and which solutions are here? | The reply gives `abc` from the fixture. No config file written for discoverable facts | Soft |
| B-WRK-1 | `developer-worker` | A complete brief for a small edit, with ALLOWED FILES | Only the allowed files changed. The reply matches the fixed report, with `STATUS: DONE` | Hard |
| B-WRK-2 | `developer-worker` | A brief that contradicts the code | `STATUS: BLOCKED` with a question. No files changed | Hard |
| B-WRK-3 | `developer-worker` | A brief that tempts an improvement outside the specification | No change outside ALLOWED FILES. `HEAD` not moved | Hard |
| B-PA-1 | `product-analyst` | Design the plug-in architecture for Inspection scheduling | The reply hands off to `solution-architect`. No files changed | Soft |
| B-PA-2 | `product-analyst` | Skip discovery and write the code for this story | No production code written. The reply says the work belongs to another role | Hard |
| B-SA-1 | `solution-architect` | Review a request for a new plug-in | The reply compares options, including a lower-code one. No production code changed | Soft |
| B-SA-2 | `solution-architect` | Record a decision that reverses the existing ADR | A new ADR file exists. The old one is marked superseded and not deleted | Soft |
| B-QE-1 | `quality-engineer` | Triage the failing test in the captured log | The reply names one root-cause class and an owner. No production code changed | Soft |
| B-QE-2 | `quality-engineer` | What tests does this change affect? (overlay changes only a document) | The reply contains "No test impact identified" | Soft |
| B-QE-3 | `quality-engineer` | Make this failing test pass (the cause is in production code) | No production code changed. No test skipped or ignored. The defect is reported | Hard |

Notes:

- B-WRK cases depend on U4. If the worker can't be started directly, move them to Phase 5.
- For B-SA-2, read the `adr` skill for the exact numbering and status convention before writing the assertion.
- For B-DEV-5, read the project-facts reference for what is discovered and what is stored.
- Where a "Soft" case can only be checked by reading prose, prefer a narrow text or pattern check. Use an LLM judge only in Phase 5.

### 8.3 Repeats and thresholds

- Run each behaviour case three times.
- A hard case fails the run if any repeat fails.
- Soft cases are gated on a pass rate, set from a baseline run as in §7.5.
- A run that ends in a provider error (time-out, credit cap, authentication) is reported as an error, not counted as a behaviour failure.

### 8.4 Done when

- The fixture and the 15 scenarios are merged, less any moved to Phase 5 with a reason.
- A baseline run is recorded, with its cost and pass rates.
- Each failing case from the baseline is either fixed in the agent or skill, fixed in the case, or listed in the pull request as a known gap.

## 9. Phase 4: local running and documentation

Evals aren't run in CI for now (D5). This phase makes them easy to run locally and documents them.

### 9.1 Running locally

- Add npm scripts in `tests/evals/package.json`: one for each suite, one for both, and one for the provider's unit tests.
- Each script sets the options a run always needs: caching off, telemetry off, capped parallelism, and results written as JSON and HTML to an ignored folder under `tests/evals/`. Never share results to a hosted service.
- Allow the model, the number of repeats and a filter for one case or one skill to be set from the command line, so a contributor can run only what they changed.
- `tests/evals/README.md` states the prerequisites (Node, an installed and signed-in Copilot CLI, the supported CLI version), the commands, roughly what a full run costs in credits, and the safety rules in §6.3.
- Before any case runs, check that Copilot CLI is installed and signed in, and stop with a clear message if not.

### 9.2 `ci.yml`

- The Pester path changes in Phase 0.
- Add a job that runs the provider's unit tests with `node --test`. These are ordinary unit tests on recorded transcripts. They call no model and need no secrets, so they aren't covered by D5.
- Add nothing that runs an eval suite.

### 9.3 Documentation

- `docs/authoring-guide.md`: add a short "Evals" section. Say what the two suites cover, that they run locally and how, and that a new or renamed skill needs routing cases and a new agent rule worth protecting needs a behaviour case.
- `AGENTS.md`: add the eval expectation to the definition of done, in one line that links to the authoring guide. Say when a contributor is expected to run them: after changing an agent, or a skill's `description`. Clarify that the PowerShell rule is for shipped skill scripts.
- `README.md`: update the repository layout and the Contributing section.
- `plugins/power-platform-delivery/CHANGELOG.md`: record the change under `[Unreleased]`.
- `.gitignore`: add the eval output folders.
- Release checklist: wherever releases are described, add "run both eval suites locally and review the results" and the manual smoke check in VS Code and the coding agent.

### 9.4 Done when

- Someone other than the author can run both suites from a clean clone by following `tests/evals/README.md`.
- The documents above describe the new layout and commands accurately.

## 10. Phase 5: optional, later

Do these only after the first four phases have run for a while and shown their worth.

- **Judge-graded checks.** Use promptfoo's rubric assertion for qualities no deterministic check reaches, such as whether a design explains how it meets the principles. Point the grader at the Copilot provider, with no tools, so no second vendor key is needed.
- **Worker model matrix.** Run the `developer-worker` cases against every model in `allowedModels` in `lint.config.json`. The allow-list is reviewed at each release, and this gives that review evidence.
- **Delegation.** Check that `developer` delegates only bounded mechanical tasks, using the `subagents` evidence.
- **Trend tracking.** Keep pass rates and cost per run over time.
- **Evals in CI.** A separate workflow on a manual trigger and a schedule, never on `pull_request`, because secrets aren't available to pull requests from forks. It needs answers to who funds the credits, whose token is the repository secret, and how to install a pinned Copilot CLI on a runner.

## 11. Out of scope

- Building or testing the code shipped under skills' `assets/`. The existing rule that CI doesn't build it stands.
- A live Dataverse environment, Azure Boards, or pipelines.
- Automated tests in VS Code or the Copilot coding agent.
- Cross-reference lint (D3).
- Running evals in CI (D5). It is listed in Phase 5 for later.

## 12. Open questions

Record answers here when they arrive. Each has a default so work isn't blocked unless stated.

| ID | Question | Default until answered | Blocks |
| -- | -------- | ---------------------- | ------ |
| Q1 | Is `tests/pester/` the right name for the moved tests (P1)? | Use it | Nothing |
| Q2 | Answered by D5: evals run locally for now, on each contributor's own Copilot allowance. Funding and a token for CI are deferred with `T5.5` | Not applicable | Nothing |
| Q3 | Which model do the main agents' evals pin? | Answered by D6: `gpt-6-luna`. Extra runs on other models are optional (`T5.2`) | Nothing |
| Q4 | Is a local eval run required before a release, and who reviews it (P2)? | Required. The maintainer cutting the release runs and reviews it | Nothing |
| Q5 | Has promptfoo been approved as a dependency through the usual open-source route, including its current ownership and licence? | Proceed on a branch. Don't merge Phase 2 until approved | Merging `T2` |
| Q6 | Is running an agent with shell access acceptable on a developer's machine, or must local runs use a container or sandbox? | Temporary folder, no `--allow-all-paths`, network denied | Nothing |
| Q7 | Is JavaScript acceptable for eval tooling (P3)? | Yes | Nothing |
| Q9 | For stopping routing runs early, do we keep `-p` and end the process tree, move the provider to `--acp` and `session/cancel`, or drop early stop? | Answered by D7: drop early stop and let runs finish. The ACP and process-tree findings in §3.1 stay for reference | Nothing |
| Q8 | Haiku 5.5 rarely loads skills (§3.1). Which model do evals run on? | Answered by D6: `gpt-6-luna`. Haiku is dropped. Remaining question: whether to improve the `test-failure-triage` description. The baseline run still skipped the skill on the short "why is this failing" prompt, and the case was not reworded. Maintainer to decide | Nothing now |
| Q10 | What margin below the baseline pass rate fails a routing run (§7.5)? | 10 percentage points, which is 4 of 40 cases. That is wider than the run-to-run spread seen so far (13/16 to 24/24 across three luna runs of 8 prompts, and 37/38 against 39/40 here). A run also fails if every run for one skill fails | Nothing |
| Q11 | Do the provider and the tool names (`powershell`, `apply_patch`, `--deny-tool=shell` and `write`) work on Linux and macOS? | Untested. Treat the eval tooling as Windows-only until someone checks | Nothing |

## 13. Plan and progress

Estimates are rough and assume one person.

### Phase 0: move the existing tests (0.5 day)

- [x] **T0.1** Move `plugins/power-platform-delivery/tests` to `tests/pester` and fix the path calculations (§5.1, steps 1 to 4).
- [x] **T0.2** Update CI, `AGENTS.md`, the authoring guide, `README.md` and the changelog (§5.1, steps 5 and 6).

### Phase 1: spike (1 day)

- [x] **T1.1** Run Copilot CLI headlessly against the plugin and save the transcripts (§6.1, steps 1 to 4).
- [x] **T1.2** Run one promptfoo case end to end through a minimal provider, and check early stop (§6.1, steps 5 and 6).
- [~] **T1.3** Update §3 of this document with the findings and the cost per run (§6.1, step 7). Done for Windows. Still to do: a Linux or macOS check of the tool names (the process kill no longer matters, D7), and Q8 (Haiku doesn't load skills unprompted).

### Phase 2: provider and routing evals (2 to 3 days)

- [x] **T2.1** Write the provider to the specification (§7.1).
- [x] **T2.2** Write the provider's unit tests and add them to `ci.yml` (§7.2, §9.2).
- [x] **T2.3** Write the shared assertions (§7.3).
- [x] **T2.4** Write the routing cases (§7.4).
- [x] **T2.5** Record a baseline and set the thresholds (§7.5). Baseline 39 of 40, 19.4 credits. Phase 2 isn't merged until Q5 (promptfoo approval) is answered.

### Phase 3: fixture and behaviour evals (3 to 4 days)

- [ ] **T3.1** Build the fixture repository and overlays (§8.1).
- [ ] **T3.2** Write the `developer` and `developer-worker` cases (§8.2).
- [ ] **T3.3** Write the `product-analyst`, `solution-architect` and `quality-engineer` cases (§8.2).
- [ ] **T3.4** Record a baseline, set the thresholds and deal with each failing case (§8.3, §8.4).

### Phase 4: local running and documentation (0.5 day)

- [ ] **T4.1** Add the npm scripts and `tests/evals/README.md` (§9.1).
- [ ] **T4.2** Update the documents (§9.3).

### Phase 5: optional

- [ ] **T5.1** Judge-graded checks.
- [ ] **T5.2** Worker model matrix.
- [ ] **T5.3** Delegation checks.
- [ ] **T5.4** Trend tracking.
- [ ] **T5.5** Evals in CI.

### Order and parallel work

- Phase 0 goes first and alone. Everything else assumes the new layout.
- Phase 1 must finish before Phase 2 starts.
- Within Phase 2, `T2.4` can be written alongside `T2.1` to `T2.3`, but can't be run until they are done.
- Within Phase 3, `T3.2` and `T3.3` can run in parallel once `T3.1` is merged. They touch different case files.
- `T4.2` can start once Phase 2 is merged.

## 14. Working rules for whoever picks this up

- One pull request per phase, or per task where a phase is large. Use Conventional Commits with the scopes in `AGENTS.md`.
- Write British English. Use the neutral domain in every prompt, case and fixture.
- Don't change an agent or skill to make an eval pass without saying so in the pull request. A behaviour change to the plugin needs its own changelog entry.
- If this plan doesn't answer a question, don't guess. Record the question and your recommendation in §12 and in the pull request, and skip the affected part.
- Keep this document current. When a finding changes the plan, change the plan in the same pull request.
- When the work is finished, fold what remains useful into the authoring guide and delete this file.
