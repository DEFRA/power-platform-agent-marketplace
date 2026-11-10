# Changelog

All notable changes to the `power-platform-delivery` plugin are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Plugin manifest for the Defra-wide rewrite (R1.1).
- `power-platform-standards` skill with the shared house rules, the technology stack and the project-facts procedure (R1.4, R1.5).
- `dataverse-plugins` skill for plug-ins and custom workflow activities (R2.1). It adopts the handler-first dependency injection scaffold (D27), shipped as tested assets: the infrastructure, the `IsExternalInit` polyfill, entity helpers, test support and 126 tests. It also covers data access, the shared-project and `UnitTest` configuration structure, and tested worked examples.
- Schema and example for `.agent-config/power-platform.json` (R1.5).
- Authoring-rule lint and Pester tests under `tests/` (R1.3).

### Removed

- The stub agents from the first scaffold, including `delivery-lead`.
