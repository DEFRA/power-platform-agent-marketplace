# Power Platform Agent Marketplace

A GitHub Copilot plugin marketplace for Defra teams building and operating services on the Power Platform.

It currently offers one plugin, `power-platform-delivery`: an opinionated agentic delivery team that works the way Defra Power Platform projects do. It supports VS Code, Copilot CLI and the Copilot coding agent.

## Install

```text
/plugin marketplace add DEFRA/power-platform-agent-marketplace
/plugin install power-platform-delivery@power-platform-agent-marketplace
```

## power-platform-delivery

The plugin ships four agents, a cheaper subagent and 21 skills. Agents describe a role and route to skills. Skills hold the procedures and can be used on their own as well as by an agent. The plugin's version is `0.1.0` and its changes are in the [changelog](plugins/power-platform-delivery/CHANGELOG.md).

### Agents

| Agent                | What it does                                                                                                                                                                              |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `product-analyst`    | Turns business goals into epics, features, stories and testable acceptance criteria. Keeps the Azure Boards backlog traceable and writes BDD scenarios when a story is picked up.         |
| `solution-architect` | Classifies the review level, compares options (including a lower-code one), places components, fits the ALM lifecycle, assesses risk and debt, and records decisions as ADRs.            |
| `developer`          | Delivers the pro-code part of a change: plug-ins, custom workflow activities, TypeScript web resources, supported customisation XML, packages, versioning and pull requests.            |
| `quality-engineer`   | Owns test strategy and the automated acceptance and integration tests, builds test data, reviews test quality, scopes a change's test impact and triages failures.                        |
| `developer-worker`   | Internal subagent, not user-invocable. Carries out one bounded task from the `developer`'s brief on a cheaper model, and returns a fixed-format report.                                  |

Agents hand off to each other in prose, for example from `product-analyst` to `solution-architect` when a story has architectural impact. The `developer` designs first and waits for approval before it builds. Low-code build (tables, columns, processes, flows, business rules and registrations) stays with the human developer, and the agents say what to change in the development environment.

### Skills

| Area                | Skills                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Shared              | `power-platform-standards` (load first: house rules, the stack and how to find project facts)                                  |
| Requirements        | `requirements-and-backlog`, `azure-boards`, `bdd-scenarios`                                                                    |
| Architecture        | `architecture-review`, `power-platform-design` (including the ALM approach), `adr`                                             |
| Development         | `dataverse-plugins`, `web-resources`, `customisation-xml`, `dataverse-schema`, `package-deployer`, `dotnet-build-verification` |
| Delivery            | `commit-and-pull-request`                                                                                                      |
| Testing             | `test-foundations`, `acceptance-testing`, `integration-testing`, `scenario-builder`                                            |
| Test quality        | `test-quality-review`, `test-impact-analysis`, `test-failure-triage`                                                           |

### How it fits your project

The plugin decides how work is done: the stack, the patterns and the quality gates. Your project supplies where things are and what they're called.

- **Discovered from the repository:** solutions and publisher prefix, plug-in, test and package projects, web resource root, base branch, repository host and model-driven app names. Agents confirm what they find with you.
- **Stored in `.agent-config/power-platform.json`:** only what can't be discovered, such as the Azure Boards organisation, project, area path and work item types. The file is checked against a [schema](plugins/power-platform-delivery/skills/power-platform-standards/assets/power-platform.schema.json) and the [project-facts reference](plugins/power-platform-delivery/skills/power-platform-standards/references/project-facts.md) describes the procedure.
- **Existing conventions win.** If a project already has its own plug-in base classes, test framework or mocking library, the skills follow them instead of migrating the project.

The plugin assumes the ALM lifecycle of [power-pipelines](https://github.com/ewingjm/power-pipelines): an ephemeral environment per work item, pull request validation against a fresh test environment, and zero manual deployment steps. Agents design and work within that lifecycle. They don't run or edit pipelines.

### Shipped code

Skills ship a small amount of code as `assets/`, for reference. Consumer repositories can copy it, but CI doesn't build or test it, and it is expected to move to NuGet and npm packages with their own lifecycle:

- `dataverse-plugins`: a handler-first dependency injection scaffold for plug-ins and custom workflow activities, with its infrastructure, entity helpers and unit test support.
- `web-resources`: the TypeScript toolchain (rollup bundles, Jest, ESLint, Prettier and an MSBuild wrapper).
- `scenario-builder`: the `RecordFaker` base class for Bogus fakers.

Skills also ship parameterised PowerShell 7 scripts, each with `-?` help and Pester tests. They look up Dataverse schema, discover and verify .NET projects, and build BDD step and scenario indexes.

## Contributing

Read [AGENTS.md](AGENTS.md) and the [authoring guide](docs/authoring-guide.md) before changing an agent, skill or script. They set out the rules, the layout and how to run the checks. CI runs the authoring-rule lint and the Pester tests on Windows and Linux. To run them locally you need PowerShell 7 and Pester 5.5 or later:

```powershell
Invoke-Pester -Path plugins/power-platform-delivery/tests -Output Detailed
```

## Repository layout

```text
.github/plugin/marketplace.json   Marketplace catalogue
.github/workflows/ci.yml          Lint and Pester tests
.github/CODEOWNERS                Code owners (no owning team yet)
docs/authoring-guide.md           Rules for agents, skills and scripts
AGENTS.md                         Guidance for agents working on this repository
plugins/<plugin>/plugin.json      Plugin manifest
plugins/<plugin>/CHANGELOG.md     Plugin changes
plugins/<plugin>/agents/*.agent.md
plugins/<plugin>/skills/<skill>/  SKILL.md, references/, assets/, scripts/
plugins/<plugin>/tests/           Lint, schemas and Pester tests
```

## Licence

Released under the [Open Government Licence v3.0](LICENSE).
