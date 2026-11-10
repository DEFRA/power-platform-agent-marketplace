# Unit testing plug-ins and custom workflow activities

Tests drive the design. Frameworks and versions are in [stack.md](../../power-platform-standards/references/stack.md). The default is MSTest, FluentAssertions below v8 and Moq. **If the project already uses a different framework or mocking library, follow it.** The examples use the defaults. Test projects target `net48`, like the code they test, because they reference the same Dataverse SDK assemblies.

One test project covers every plug-in and workflow project. Build and run it in the `UnitTest` configuration (`dotnet test -c UnitTest`), so that it sees each shared class once. See [project-structure.md](project-structure.md).

## Test-driven loop

1. **Red.** Write one test that states a behaviour. Run it and confirm it fails for the right reason. A missing member is a compile failure, not a meaningful red, so add the smallest stub that lets the test fail on behaviour.
2. **Green.** Write the smallest production code that passes. Run the tests again.
3. **Refactor.** Remove duplication and improve names while the tests stay green. Don't change behaviour while refactoring.

Rules:

- Test behaviour through the public surface, not private members or call order, unless the call is the behaviour (a write that must or must not happen).
- Order the tests from the simplest case to the most general: the no-op case, one configured mapping, then several.
- **Every configuration-driven class has a test that supplies a second, different configuration** and shows the behaviour changes with no code change. This is the proof that nothing is hard-coded.
- Hard-to-test code is a design signal. Inject the dependency or extract a class instead of adding a workaround.
- A bug fix starts with a test that reproduces the bug and fails.

## Conventions

- Mirror the source folders and namespaces. Name test classes `<Subject>Tests` and test methods `Method_Scenario_ExpectedResult`.
- Use `[TestMethod]`, or `[TestMethod]` with `[DataRow]` for a set of equivalent cases. MSTest creates a new class instance for each test, so create the subject and mocks in fields or the constructor. Share no mutable state between tests.
- Follow the project's layout for `using` directives, XML documentation and analyser rules. Add no warnings and no suppressions.
- Use constants, generated names and `nameof` rather than literals where the production code does.

## Mocks and test data

- Mock `IOrganizationService` and the logger. Use `MockBehavior.Strict` for the service only when a test must prove nothing else was called. Set up every call you assert on, and assert writes with `Verify` and `Times`.
- If the code under test calls `ToEntity<T>()` or reads typed properties, return early-bound entities from mocks. Otherwise a late-bound `Entity` is fine, and it is the right choice for names that arrive through configuration.
- Set up the call the code makes. A `QueryExpression` goes through `RetrieveMultiple`. A query built through LINQ reaches the service as `Execute(RetrieveMultipleRequest)`.
- Assert a write by the entity and attributes passed to `Create` or `Update`: use `Verify` with a predicate, or capture the entity with `Callback`.
- Build `Create` and `Update` targets with only the attributes the scenario supplies. Every other attribute must read as absent, as in Dataverse.

## What to test

- **Settings parsing.** Valid input, then each missing, malformed or incomplete case, with a clear failure and no writes.
- **Business logic class.** Construct it with mocks. Test each rule, the writes it makes, the cases where it must write nothing (`Times.Never`), the values it logs, and that an input entity isn't modified unless that is the purpose.
- **Plug-in, end to end.** Mock `IServiceProvider` to return `ITracingService`, `IPluginExecutionContext` and an `IOrganizationServiceFactory` whose `CreateOrganizationService` returns the service mock. Set the message name, `InputParameters` (`Target`) and any images on the context mock, then call `Execute(serviceProvider)`. Cover each message, stage or image variation the plug-in handles, the do-nothing case, and error handling.
- **CWA, end to end.** Wrap it in a `WorkflowInvoker`, add `ITracingService`, `IWorkflowContext` and `IOrganizationServiceFactory` as extensions, and call `Invoke` with a dictionary keyed by the argument property names. Read outputs from the returned dictionary. Test each required input, the outputs and the service calls.
- **Utilities and extensions.** Test each mapping and edge case, using `[DataRow]` where the cases are equivalent.

## Checklist

- Each test was written first and seen to fail before its code existed.
- A test supplies a second, different configuration (or set of inputs) and shows the behaviour changes.
- Missing, malformed or incomplete configuration fails with a clear message and writes nothing.
- Each message, stage or image variation the plug-in handles has a test, and so does the do-nothing case, which sends the service no write.
- An `Update` target holds only the changed attributes, so logic that needs other values reads them from the pre-image. A test uses a target that lacks them.
- A missing pre-image or lookup is handled as the design says.
- Each required CWA input missing gives the expected failure, and each output is set.
- Writes are asserted by entity and attributes, and the input target isn't mutated unless that is the purpose.
- The new test files add no analyser warnings.
