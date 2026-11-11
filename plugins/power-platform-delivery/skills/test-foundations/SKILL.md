---
name: test-foundations
description: Shared groundwork for automated Power Platform tests. Covers how a run gets its configuration, pooled test users and personas, and a Dataverse client per persona, when those resources are created and released, and the assertion, retry and logging conventions. Use for acceptance or integration tests that sign in as, or call the API as, different users, or that run in parallel.
---

# Test foundations

Intended for `quality-engineer` and `developer`, but usable by anyone. Load `power-platform-standards` first. This skill holds what acceptance tests and integration tests have in common, so neither repeats it:

- `acceptance-testing` signs in to the app as a persona and drives the UI.
- `integration-testing` calls the API as a persona and checks the result.
- `scenario-builder` builds the data both of them need, with events that act as personas.

All three assume what is here: a configured environment, a user for each persona and a client for each user. Tests run unattended against a freshly deployed environment (see [alm.md](../power-platform-design/references/alm.md)), so every test gets its own users, clients and data and leaves nothing behind.

| Reference | Load it when |
| --- | --- |
| [users-and-personas.md](references/users-and-personas.md) | Defining a persona, or touching the user pool: leases, static and pooled users, verification, extensions |
| [clients.md](references/clients.md) | Getting a Dataverse client for a persona or user, or deciding who disposes it |
| [configuration.md](references/configuration.md) | Reading environment settings, personas or credentials, and keeping secrets out of the repository |
| [run-lifecycle.md](references/run-lifecycle.md) | Setting up or releasing shared resources: run and test start-up and teardown, parallelism, framework hooks |
| [common-conventions.md](references/common-conventions.md) | Writing any test code: assertions, defensive coding, waits and retries, logging |

## Project's own implementation first

This skill describes what the infrastructure must do. It ships no code. Most projects already have a user pool, a client factory and hooks. Find them (see [project-facts.md](../power-platform-standards/references/project-facts.md)), follow them and say where they fall short of the references. Don't add a second mechanism or replace a working one unprompted. If the project has none, propose one and wait for approval.

## Rules every test follows

- **A test runs as one user** from the pool, asking for personas and never for roles. Roles are assigned through persona configuration, not in a step, event or test.
- **Each test builds its own data and clients** and shares nothing mutable with another test. It can run alone and in parallel.
- **Acting as the right identity.** Use the persona that owns the behaviour. Don't default to an administrator or the application user.
- **Secrets stay out of code, tests, logs and the repository.**
- **Wait on conditions, not time.** A bounded retry around the specific check, never a fixed delay.
- **Failures explain themselves.** Setup and requests are logged, and precondition failures are in domain language.
