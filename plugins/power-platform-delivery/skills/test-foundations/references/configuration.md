# Test configuration

How a test run learns which environment to use, which personas exist and how to authenticate. This applies to acceptance and integration tests alike.

## Layers

Layer the sources, with later ones winning:

1. **A checked-in JSON file** for non-secret values: the environment URL, the application registration's identifiers and the persona definitions.
2. **Environment variables** with a project-specific prefix, which pipelines use to supply values.
3. **User secrets**, for a developer's machine.
4. **A key vault**, for credentials such as user passwords. The only secret a developer needs locally is what lets the run reach the vault.

## Rules

- Read the configuration once at the start of the run and register it for everything else to use. Don't read files or environment variables from steps, events or tests.
- **Validate** it at the start and fail fast. Name the missing or invalid key, never its value.
- Pipelines supply secrets through the environment or the vault, never through files. Nothing secret is committed.
- Never log, echo or commit a credential. If you find one in the repository, tell the user and don't repeat it.
- If a start-up step fails, report only non-secret identifiers, such as the environment URL, the vault name and client ID, so it's clear which target was used without exposing credentials.
- The environment URL is configuration, so the same tests run against a freshly created pull request environment and a static one.
- Test users need a consistent locale and time zone. Set them at the start of each run (see [run-lifecycle.md](run-lifecycle.md)).
- Feature flags held as environment variables can be read once at the start and used to skip, rather than fail, tests that don't apply to a flag's value.
