# Symptoms and likely causes

Signs that point toward each category. They are leads, not proof. Confirm against the evidence before you classify.

## Environment issue

- A timeout waiting for a user, or "no user is available", means the pool is too small for the parallel workers, or users are stuck leased from an earlier run.
- A start-up failure listing discrepancies for static users means their roles, teams or business unit have drifted from the persona configuration, or a user is disabled.
- The whole run fails before any scenario starts: missing or invalid configuration, a secret that isn't available, or an environment that isn't reachable.
- Every scenario that uses one table or app fails: the solution or package didn't deploy fully, or the app isn't published.
- A scenario needs reference data (a category, a type) that isn't there: the package's seed data is missing it, or the data was changed in a shared environment.
- Date or number assertions that differ by locale or time zone: test users' settings aren't normalised.
- A scenario skipped as inconclusive: a feature flag has a different value in this environment.
- Intermittent authentication, "Xrm is not defined" or throttling errors that clear on a clean retry.

## Test implementation defect

- It fails in a `Given` or `When`, in setup, or while waiting, before the behaviour under test.
- A null reference, an unbound step or a missing key for a prior event's outputs: a step or builder chain is incomplete, such as a missing `AndAllPreviousSteps()`.
- Passes alone, fails in a run, or fails only in a different order: shared state, a shared user or record, or a client shared across threads.
- A fixed delay, or a race with an asynchronous process: the wait isn't a bounded retry on the condition.
- A faker generates a value that breaks a column's constraint, so the platform rejects the create.
- A hard-coded ID, name or URL that doesn't exist in this environment.
- The test asserts something the scenario doesn't say.

## Scenario defect

- The test does what the scenario says and the system does something reasonable that the scenario doesn't allow for.
- Two scenarios contradict each other, or a step's wording means different things to the binding and to the reader.
- The scenario describes behaviour that the criteria never asked for.

## Requirement defect

- The criteria conflict, or leave a case open, so the system, the scenario and the test each reasonably differ.
- The behaviour was changed deliberately and the criteria weren't updated.

## Production defect

- Setup succeeded and the action ran as intended, but the observable result differs from a correct scenario.
- A plug-in trace log shows an exception, or a flow run failed, for the record the test created.
- The failure reproduces by hand in a development environment.
- A recently changed component in the diff explains the new failure (see `test-impact-analysis`).
- A permission test fails because a role gives more or less access than the design says.
