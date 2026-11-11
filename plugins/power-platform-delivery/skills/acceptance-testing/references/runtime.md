# Reqnroll wiring, login and diagnostics

The parts of an acceptance test run that are specific to Reqnroll and Power Playwright. The stages, the rules for resources and clean-up, parallelism and timeouts are in `test-foundations` ([run-lifecycle.md](../../test-foundations/references/run-lifecycle.md)). Users and clients are in [users-and-personas.md](../../test-foundations/references/users-and-personas.md) and [clients.md](../../test-foundations/references/clients.md). Projects often have their own versions: check that a project's covers these points, and extend it.

## Hook order

Reqnroll builds its container from hooks, and `Order` values control what exists when. Follow the stages in `run-lifecycle.md`, with configuration and registration first (large negative values) and clean-up last (large positive values). Acceptance tests add these steps:

| When                 | Acceptance-specific hooks                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| Before the run       | Start Playwright, after the pool and base client exist                                                  |
| Before each scenario | Create the Power Playwright instance, before the scenario builder factory, which is registered last     |
| After each scenario  | Stop tracing, after the user is released. Dispose the browser before the clients and the client factory |

Register run-level services on the test thread container. Register scenario-level ones on the scenario's container, so scenarios don't interfere.

## Reqnroll configuration

- Set `missingOrPendingStepsOutcome` to `Error`, so an unbound step fails instead of passing quietly.
- Parallelism and timeouts are in the run settings (see `run-lifecycle.md`). Keep Playwright debugging options off in pipelines.

## Login and browser state

- Launch a new browser per scenario, with its own context, and register both in the container so after-hooks can reach them.
- Cache each user's signed-in browser state to a temporary file and reuse it for later scenarios with the same user, so login isn't repeated. Discard the file once it is old enough that it could expire in the middle of a run: sign-in cookies last about a day, so about 20 hours is safe.
- If launching with saved state fails, or the app reports that `Xrm` isn't defined, close the browser and retry once with a clean context. Don't fall back silently otherwise.
- Resolve a persona from its alias in the configuration, and fail with a message naming the alias if there is none or if it maps to several personas where one is needed.
- Provide a login variant that asks for exactly the named personas, for scenarios that prove limited access.

## Diagnostics

Start Playwright tracing for every scenario, with screenshots, snapshots and sources. On a failure, save the trace, named after the scenario, to the results directory and attach it to the test result. On success, stop tracing without saving.

## Feature flags

Flag values are read once at the start of the run (see [configuration.md](../../test-foundations/references/configuration.md)). Let a tag on a scenario declare the value it needs. A before-scenario hook for that tag marks the scenario inconclusive when the flag differs, so it is skipped and not reported as a failure.
