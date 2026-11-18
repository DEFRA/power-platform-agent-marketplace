# Authoring guide

How to add and change agents, skills and scripts in `power-platform-delivery`. CI enforces the mechanical ones.

## Principles

- **Every fact lives in one place.** Agents state a role, route to skills and describe handoffs. Skills hold the procedure. Detail goes in a skill's `references/` and is loaded only when needed. Link instead of repeating.
- **Opinionated defaults, project-supplied facts.** The plugin decides how work is done. The project says where things are and what they're called.
- **No project history.** Nothing specific to one project ships in the plugin: names, prefixes, domain examples or migration notes. Examples use *Case / Applicant / Inspection* and the prefix `abc_`.

## Layout

```text
plugins/power-platform-delivery/
  plugin.json
  agents/<agent-id>.agent.md
  skills/<skill-name>/
    SKILL.md
    references/*.md      loaded on demand, one level deep
    assets/*             templates copied into consumer repos
    scripts/*.ps1        parameterised and Pester-tested
```

Tests live outside the plugin, so they don't ship with an install:

```text
tests/pester/            lint, schemas and Pester tests, mirroring the skills' folders
tests/evals/             evals that run the agents against a model, and their unit tests
```

## Rules

| Rule                              | Limit or convention                                                                                                                                                                                                                            |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent file length                 | 100 lines of body at most                                                                                                                                                                                                                      |
| `SKILL.md` length                 | 150 lines of body at most. Move detail to `references/*.md`, one level deep                                                                                                                                                                    |
| `description` (agents and skills) | Third person. Says what and when. 400 characters at most. No repo paths or project names. Quote it if it contains `: `                                                                                                                         |
| Skill `name`                      | kebab-case and the same as the folder name                                                                                                                                                                                                     |
| Agent frontmatter                 | `name` (the same as the file name), `description` and, only when restricting, `tools` using the portable aliases `read`, `edit`, `search`, `execute`, `web`, `agent` and `todo`. No `handoffs`. No `model`, except on `developer-worker`     |
| Handoffs                          | In prose, naming agents by id: "hand off to `solution-architect` when…"                                                                                                                                                                        |
| Ownership                         | Use soft "Intended for" wording. Never hard-gate a skill to one agent                                                                                                                                                                          |
| Links                             | Relative links inside the plugin only. Never link to a path in a consumer repo                                                                                                                                                                 |
| Scripts                           | PowerShell 7 that works on Windows and Linux. Every input is a parameter, with no project defaults. Each has `-?` help and Pester tests in `tests/pester/`                                                                                            |
| Examples                          | The neutral domain above                                                                                                                                                                                                                       |
| Language                          | British English                                                                                                                                                                                                                                |

The numbers and allowed values are in [lint.config.json](../tests/pester/lint.config.json), the single place CI reads them from.

## Project facts

Agents and skills never hard-code solution names, prefixes, paths, project names or app names. They discover facts from the repository, confirm them with the user, and store only what can't be discovered in `.agent-config/power-platform.json`. The procedure, the sources for each fact and the config format are in the [project-facts reference](../plugins/power-platform-delivery/skills/power-platform-standards/references/project-facts.md). If you add a fact, add it there. Don't add it to a skill.

## Checking your changes

CI runs on Windows and Linux. To run the same checks locally you need PowerShell 7 and Pester 5 (5.5 or later):

```powershell
Invoke-Pester -Path tests/pester -Output Detailed
```

The checks cover frontmatter, line budgets, in-plugin links, the JSON schemas for the manifests and project config, the `model` allow-list, and the tests for every script.

## Evals

Evals run the agents and skills against a model and check what they do. They live in [tests/evals](../tests/evals/README.md), which also covers running them, what they cost and the safety rules. They run on your machine, on your Copilot allowance. Results vary between runs, so they never run in CI and never gate a pull request.

- **Routing:** does a natural prompt load the intended skill? Every skill except `power-platform-standards` has two cases in `cases/routing.yaml`.
- **Behaviour:** does an agent keep a rule its file states? Each agent has cases in `cases/behaviour/<agent>.yaml`, run read-only against a small fixture repository.

**When to run them.** After changing an agent, or a skill's `description`. From `tests/evals`, run `npm run eval:routing` or `npm run eval:behaviour`, filtered to what you changed (`-- --filter-pattern "adr"`).

**When to add a case.** A new or renamed skill needs two routing cases. A new agent rule worth protecting needs a behaviour case, and the case's description quotes the sentence the rule comes from. If you can't find the sentence, the case doesn't belong.

**Reading a failure.** Every case is expected to pass, and a failure is a finding, not a number to tune. Repeat a failing case (`-- --repeat 3`) before concluding anything, because the same case can pass and fail with no change in between. Then decide whether the agent or skill text, or the case, is wrong, and say which in the pull request. Don't change an agent or skill just to make an eval pass without saying so. A change to an agent's or skill's behaviour needs its own changelog entry.

## Releasing

Before cutting a release:

- Run both eval suites locally and review the results.
- Smoke check the plugin in VS Code and in the Copilot coding agent. The evals drive Copilot CLI only.
- Review the `model` allow-list in [lint.config.json](../tests/pester/lint.config.json).

## Commits and tracking

Use Conventional Commits, for example `feat(skills): add dataverse-plugins skill`, with the scopes `agents`, `skills`, `plugin`, `ci` and `docs`. Record every change under `[Unreleased]` in the plugin's `CHANGELOG.md`. If the docs don't answer a question, put the question and your recommendation in the pull request description rather than guessing.
