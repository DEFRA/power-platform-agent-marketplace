# Common test conventions

The rules shared by acceptance and integration tests. Both build their preconditions with ScenarioBuilder and share these expectations, so they are stated once, here.

Terms used across the testing skills:

- **Precondition code**: a `Given` or `When` step in an acceptance test, or the Arrange and Act parts of an integration test.
- **Verification code**: a `Then` step, or the Assert part of a test.

The default libraries and versions, including FluentAssertions below v8, are in [stack.md](../../power-platform-standards/references/stack.md). A project that already has a different assertion library or logging convention keeps it.

## Assertions

- Verification code uses FluentAssertions (`.Should()`). Don't use bare `Assert.*`, or an `if` that throws.
- Assertion-library exceptions belong only in verification code. **Precondition code never throws one.** If a precondition fails, throw a plain exception in domain language (see below).
- Prefer asserting a table or collection of expected values in one step to many single-field assertions.
- Group related assertions in an `AssertionScope`, so every failure is reported together instead of the first hiding the rest, and give each assertion a reason:

  ```csharp
  using (new AssertionScope($"case {actualCase.Id}"))
  {
      actualCase.Status.Should().Be(expectedStatus, because: "the case should have moved to the expected status");
      actualCase.StatusReason.Should().Be(expectedReason, because: "the case should record why its status changed");
  }
  ```

## Defensive coding

- Expect failure at every junction: data setup, navigation, waiting on asynchronous processes and UI or API calls, not only the final assertion.
- When precondition code can fail, such as a poll for a record created asynchronously that times out, throw an easy-to-diagnose exception in domain language. Prefer "The inspection for case '{caseId}' wasn't created within the expected time" to "records did not appear within 180s". Name the record involved.

## Waiting and retries

- Wait for eventually consistent work, such as a flow, a plug-in on an asynchronous step or an integration updating a record, with a bounded retry helper around the specific check. Use the project's helper (commonly `RetryUntilSucceedsAsync` in the shared test-data project), or a client option such as a wait-for-deletion parameter where the API has one.
- If the project has no helper, add a small one to the shared test-data project: a fixed number of attempts, a fixed delay, a logged message for each failed attempt, and the last exception rethrown when attempts run out. That needs no retry library.
- Never assert straight after starting an asynchronous process. Never use a bare `Task.Delay` or `Thread.Sleep` as the wait: it is either too short and flaky, or too long and slow, and it doesn't say what is awaited. Treat an existing one as debt to fix, not a pattern to copy.

## Logging

- Register ScenarioBuilder builders with a real `ILogger` that writes through the test framework's output, never a null logger. Setup is then diagnosable from CI output, not only from a local run.
- Log every Dataverse or API request made during setup with the operation and the identifying values of its payload ("creating case {CaseId} for applicant {ApplicantId}"), not only that a request happened. Use structured messages, not string concatenation.
- Log key waits, retries and non-obvious actions in steps and tests through the same logger.
- The same goes for verification code: log the action under test and the state retrieved to verify it, so a failing assertion can be diagnosed from CI logs without reproducing it locally.
- Never log credentials, tokens or connection strings. When reporting a failure in start-up hooks, include only non-secret identifiers such as the environment URL.
