# Run lifecycle

When the shared test resources are created and released, so tests run in parallel and fail in ways that can be diagnosed. The stages are the same for acceptance and integration tests. Only the framework hooks differ. A project often has its own version of this: check that it covers the points below, and extend it instead of adding a second mechanism.

## Stages

| Stage          | What happens                                                                                                                                                                                                                                    |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Run start**  | Register loggers and read configuration (first). Build the user pool and the one base client. Verify static users. Normalise the test users' settings, such as locale and time zone. Read feature flags. Acceptance tests also start Playwright |
| **Test start** | Create a new client factory, then the test's clients, then anything per test that needs them, such as a Power Playwright instance or the scenario builder factory (last, because it needs the others)                                           |
| **Test end**   | Release the user first, and make sure it runs even when the test failed. Save diagnostics on failure. Dispose browsers, clients and the client factory last                                                                                     |
| **Run end**    | Dispose the pool, the base client and any client held for run-level steps                                                                                                                                                                       |

## Rules

- Resources shared by the run, such as the pool, base client and Playwright, are created once. Everything specific to a test is created per test, so tests don't interfere with each other.
- Register dependencies in one place, the hook or initialisation class, in an order set by explicit order values. Configuration and registration come first, with clean-up last. Don't scatter registrations through steps or tests.
- A clean-up step never throws. Catch the error, write it to the test's output and carry on, so one failed disposal doesn't hide the test's result or leak the rest.
- A start-up step that fails writes a clear message to the console and error streams, then rethrows. Include only non-secret identifiers (see [configuration.md](configuration.md)).
- Write user-pool actions (waiting for a user, which user was acquired, release) to the test's output, so a CI log shows who ran what.
- Setup that needs a client at run start, before any test, uses a separate application-user client, not a test's client.

## Framework hooks

| Stage      | Reqnroll (acceptance)           | MSTest (integration)                            |
| ---------- | ------------------------------- | ----------------------------------------------- |
| Run start  | `[BeforeTestRun]` with `Order`  | `[AssemblyInitialize]`                          |
| Test start | `[BeforeScenario]` with `Order` | `[TestInitialize]`, or a base class constructor |
| Test end   | `[AfterScenario]` with `Order`  | `[TestCleanup]`                                 |
| Run end    | `[AfterTestRun]` with `Order`   | `[AssemblyCleanup]`                             |

Reqnroll can order several hooks and inject the container. MSTest has one method per stage, so a base class or helper calls the steps in order. The Reqnroll-specific order, container and diagnostics are in `acceptance-testing` (`runtime.md`). Integration tests have no UI, so they need none of the browser steps.

## Parallelism and timeouts

Set these in the run settings, not in code:

- Run tests in parallel at method level with a fixed number of workers. The worker count can't exceed what the user pool and the environment can serve.
- Set a timeout generous enough for the slowest test, but finite.
- Retries, if the project uses any, are bounded and configured, not applied globally. A retry that hides a failure is debt: send the cause to `test-failure-triage`.
- Run headless in pipelines, switched by an environment variable.
