# Changelog

All notable changes to the `power-platform-delivery` plugin are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-11

The first release: an agentic team that Defra teams install to deliver Power Platform projects. It works in VS Code, Copilot CLI and the Copilot coding agent.

### Added

#### Agents

- `product-analyst`: turns business goals into epics, features, user stories and testable acceptance criteria, manages Azure Boards work items and writes BDD scenarios.
- `solution-architect`: classifies the review level, compares options (including a lower-code one), designs within the ALM lifecycle and records decisions as ADRs.
- `developer`: pro-code delivery for plug-ins, custom workflow activities, TypeScript web resources, supported customisation XML and package deployer projects. Low-code build stays with the human developer.
- `developer-worker`: an internal subagent that carries out one bounded task from the developer's brief, pinned to a cheaper model. It isn't user-invocable.
- `quality-engineer`: owns test strategy, acceptance and integration tests, test data, test review and failure triage.

#### Skills

- Shared: `power-platform-standards`, the house rules, the technology stack and how project facts are discovered and stored in `.agent-config/power-platform.json`, with a schema and an example.
- Product analysis: `requirements-and-backlog`, `azure-boards` and `bdd-scenarios`.
- Architecture: `architecture-review`, `power-platform-design` (including the ALM reference and a deprecated-components template) and `adr`.
- Development: `dataverse-plugins`, `web-resources`, `customisation-xml`, `dataverse-schema`, `package-deployer`, `dotnet-build-verification` and `commit-and-pull-request`.
- Quality: `test-foundations`, `acceptance-testing`, `integration-testing`, `scenario-builder`, `test-quality-review`, `test-impact-analysis` and `test-failure-triage`.

#### Scripts

PowerShell 7 and cross-platform. Every input is a parameter, each script has `-?` help, and each has Pester tests.

- `dotnet-build-verification`: `Find-VerificationProject.ps1`, `New-WarningBaseline.ps1` and `Test-Change.ps1`. They discover the projects to build, take a warning baseline before the first C# edit, then gate a change on a rebuild, the warnings diff and the unit tests.
- `dataverse-schema`: `Get-EntityFieldMetadata.ps1` and `Get-EntityPropertyClrType.ps1`, which report column constraints from the unpacked solution and the exact generated CLR types.
- `bdd-scenarios`: `Build-StepIndex.ps1` and `Build-ScenarioIndex.ps1`, which index step bindings and scenarios so existing steps are reused.

#### Code assets for reference

Skills ship a small amount of code as `assets/`. CI doesn't build or test it, and it is expected to move to NuGet and npm packages with their own lifecycle.

- `dataverse-plugins`: a handler-first dependency injection scaffold for plug-ins and custom workflow activities (the container, `PluginBase<THandler>`, `WorkflowActivityBase<THandler>`, execution services, logging, step constants and the `IsExternalInit` polyfill), entity helpers, test support and 137 unit tests that document its behaviour.
- `web-resources`: the TypeScript toolchain (rollup IIFE bundles with namespaces derived from file names, Jest, ESLint, Prettier, an MSBuild wrapper and a bundle contract test).
- `scenario-builder`: the `RecordFaker` base class for Bogus fakers.

#### Plugin tooling

- Plugin manifest and marketplace catalogue, with JSON schemas for both.
- Authoring-rule lint (frontmatter, line budgets, in-plugin links and the model allow-list) and Pester tests under `tests/`, run by CI on Windows and Linux.
