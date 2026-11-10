# Authoring guide

How to add and change agents, skills and scripts in `power-platform-delivery`. The reasoning behind these rules is in [productionisation-plan.md](productionisation-plan.md). CI enforces the mechanical ones.

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
  tests/                 lint, schemas and Pester tests
```

## Rules

| Rule | Limit or convention |
| --- | --- |
| Agent file length | 100 lines of body at most |
| `SKILL.md` length | 150 lines of body at most. Move detail to `references/*.md`, one level deep |
| `description` (agents and skills) | Third person. Says what and when. 400 characters at most. No repo paths or project names. Quote it if it contains `: ` |
| Skill `name` | kebab-case and the same as the folder name |
| Agent frontmatter | `name` (the same as the file name), `description` and, only when restricting, `tools` using the portable aliases `read`, `edit`, `search`, `execute`, `web`, `agent` and `todo`. No `handoffs`. No `model`, except on `developer-worker` (D11) |
| Handoffs | In prose, naming agents by id: "hand off to `solution-architect` when…" |
| Ownership | Use soft "Intended for" wording. Never hard-gate a skill to one agent |
| Links | Relative links inside the plugin only. Never link to a path in a consumer repo |
| Scripts | PowerShell 7 that works on Windows and Linux. Every input is a parameter, with no project defaults. Each has `-?` help and Pester tests in `tests/` |
| Examples | The neutral domain above |
| Language | British English |

The numbers and allowed values are in [lint.config.json](../plugins/power-platform-delivery/tests/lint.config.json), the single place CI reads them from.

## Project facts

Agents and skills never hard-code solution names, prefixes, paths, project names or app names. They discover facts from the repository, confirm them with the user, and store only what can't be discovered in `.agent-config/power-platform.json`. The procedure, the sources for each fact and the config format are in the [project-facts reference](../plugins/power-platform-delivery/skills/power-platform-standards/references/project-facts.md). If you add a fact, add it there. Don't add it to a skill.

## Checking your changes

CI runs on Windows and Linux. To run the same checks locally you need PowerShell 7 and Pester 5 (5.5 or later):

```powershell
Invoke-Pester -Path plugins/power-platform-delivery/tests -Output Detailed
```

The checks cover frontmatter, line budgets, in-plugin links, the JSON schemas for the manifests and project config, the `model` allow-list, and the tests for every script.

## Commits and tracking

Use Conventional Commits and the plan's task ID, for example `feat(skills): add dataverse-plugins skill (R2.1)`. Update the task in [section 8 of the plan](productionisation-plan.md#8-plan-and-progress) when you start it (`[~]`) and when you finish it (`[x]` with the pull request link). If the plan doesn't answer a question, add it to section 6 as `O<n>` with a recommendation rather than guessing.
