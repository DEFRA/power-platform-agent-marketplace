# Changelog

All notable changes to the `power-platform-delivery` plugin are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Plugin manifest for the Defra-wide rewrite (R1.1).
- `power-platform-standards` skill with the shared house rules, the technology stack and the project-facts procedure (R1.4, R1.5).
- `dataverse-plugins` skill for plug-ins and custom workflow activities (R2.1). It adopts the handler-first dependency injection scaffold (D27), shipped as tested assets: the infrastructure, the `IsExternalInit` polyfill, entity helpers, test support and 126 tests. It also covers data access, the shared-project and `UnitTest` configuration structure, and tested worked examples.
- `dotnet-build-verification` skill with project discovery, a warning baseline and a build, warnings and tests gate (R2.6).
- `web-resources` skill with the TypeScript toolchain as assets: namespaces derived from file names and a bundle contract test (R2.2).
- `customisation-xml`, `dataverse-schema` (schema lookup scripts and `pac modelbuilder`), `package-deployer` and `commit-and-pull-request` skills (R2.3, R2.4, R2.5, R2.7).
- `developer` agent and `developer-worker` subagent, which is pinned to a cheaper model (R2.8).
- Schema and example for `.agent-config/power-platform.json` (R1.5).
- Authoring-rule lint and Pester tests under `tests/` (R1.3).
- `requirements-and-backlog` skill for discovery, backlog breakdown, acceptance criteria, readiness and prioritisation (R4.1).
- `azure-boards` skill for reading and changing work items safely, configured from the shared project config (R4.2).
- `bdd-scenarios` skill for deciding which acceptance criteria to automate and writing feature files, with the parameterised `Build-StepIndex.ps1` and `Build-ScenarioIndex.ps1` index scripts and their Pester tests (R4.3).
- `architecture-review`, `power-platform-design` (including the ALM reference) and `adr` skills (R4.4). The project-facts reference gains a row for the architecture records.
- `product-analyst` and `solution-architect` agents (R4.5).

### Removed

- The stub agents from the first scaffold, including `delivery-lead`.
