# Unit testing plug-ins and custom workflow activities

Tests drive the design. Frameworks and versions are in [stack.md](../../power-platform-standards/references/stack.md). The default is MSTest, FluentAssertions below v8 and Moq. **If the project already uses a different framework or mocking library, follow it.** The examples use the defaults. Test projects target `net48`, like the code they test, because they reference the same Dataverse SDK assemblies.

One test project covers every head. Build and run it in the `UnitTest` configuration (`dotnet test -c UnitTest`), so that it sees each shared class once (see [project-structure.md](project-structure.md)). The [test support classes](../assets/UnitTests/Support/) simulate the plug-in and workflow hosts. Copy them with the infrastructure (see [infrastructure.md](infrastructure.md#test-support)).

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

- Name test classes `public sealed class <Subject>Tests` and test methods `Method_Scenario_ExpectedResult`. Mirror the source folders and namespaces: tests for `Abc.Plugins.FieldCopying` go in `Abc.UnitTests.Plugins.FieldCopying`.
- Use `[TestMethod]`, or `[TestMethod]` with `[DataRow]` for a set of equivalent cases. MSTest creates a new class instance for each test, so create the subject and mocks in fields or the constructor. Share no mutable state between tests.
- Follow the project's layout for `using` directives and analyser rules. Add no warnings and no suppressions. The test project turns off only the documentation rules.
- Use constants, generated names and `nameof` rather than literals where the production code does.

## Mocks and test data

- Use strict mocks (`MockBehavior.Strict`) for `IOrganizationService` and for the services a handler calls. The runtimes' service mocks are already strict. Set up every call the code makes, so an unexpected read or write fails the test.
- End a failure test with `VerifyNoOtherCalls()` to prove nothing was read or written. The `Assert…FailsWithoutCallingService` helpers in the test bases do this for you.
- Assert a write by its record and exactly the attributes it holds. Capture the entity with `Callback`, then check its reference and `Attributes.Keys`, or use `Verify` with a predicate.
- Return early-bound entities when the code calls `ToEntity<T>()`, reads typed properties or queries through LINQ. A late-bound `Entity` is the right choice for names that arrive through configuration.
- Set up the call the code makes. `Retrieve` and `RetrieveMultiple` are set up directly. A LINQ query reaches the service as `Execute(RetrieveMultipleRequest)`, which `ReturnsRecords` handles (see [data-access.md](data-access.md#testing-data-access)).
- Build `Create` and `Update` targets with only the attributes the scenario supplies. Every other attribute must read as absent, as in Dataverse.

## What to test

### Settings and application services

- **Settings parsing.** Valid input, then each missing, malformed or incomplete case, with a clear failure. Include a second, different configuration.
- **Application service.** Construct it with strict mocks, or with a real context over a strict service mock. Test:
  - null checks on the constructor and method arguments;
  - each rule, and each case where it must write nothing;
  - the exact writes, their attributes and their order;
  - that the input entities are unchanged afterwards;
  - what it logs when it decides to do nothing;
  - each bug that is kept on purpose (see "Changing existing code" in the skill).

### Queries

Test each query class against a real context over a strict service mock, as [data-access.md](data-access.md#testing-data-access) shows. Cover the conditions, the columns read, the mapping to the result type, and the empty result.

### Input contexts and projections

Test each projection extension for every field mapping, that unsupplied attributes project as null, and that the source entity is unchanged (see [data-access.md](data-access.md#narrow-input-contexts)).

### Handlers

Construct a plug-in handler directly, with a strict mock of its application service, `PluginRuntime.CreateExecution()` and a `PluginStepConfiguration`. Arrange the step on the `PluginRuntime` with `ForStep`, `WithTarget` and `WithPreImage` or `WithPostImage`. [plugin-example.md](plugin-example.md) shows the tests. Test:

- null checks on each constructor argument;
- that a valid step makes one call to the application service, with the target, image and settings;
- message names in any case (`"create"`, `"UPDATE"`);
- that each contract failure (another message, stage or mode, no `Target`, a missing image) throws `InvalidOperationException` and calls nothing;
- that a failure from the application service propagates, because handlers don't catch.

A workflow handler can't be constructed in a test, because only the workflow runtime can create a `CodeActivityContext`. Test it through its activity.

### Plug-ins, end to end

Derive the test class from `PluginTestBase<TPlugin>`. Override `CreatePlugin()` to pass step configuration, arrange `this.Runtime`, and call `this.Execute()`. Test:

- that the class derives from `PluginBase<THandler>` for its handler;
- one happy path for each registered step, asserting the writes;
- one contract failure, through `AssertExecuteFailsWithoutCallingService()`. It expects an `InvalidPluginExecutionException` and proves the service wasn't called;
- that an unexpected failure reaches the user as an `InvalidPluginExecutionException` with the cause as its inner exception (throw a `SimulatedFailureException` from the service mock);
- that a do-nothing path traces why (`this.Runtime.Tracing.Messages`) and writes nothing.

### Activities, end to end

Derive the test class from `WorkflowActivityTestBase<TActivity>`. Set the primary record on `this.Runtime.Context`, call `this.Invoke(nameof(TActivity.Argument), value)`, and read outputs from the returned dictionary by property name. [workflow-activity-example.md](workflow-activity-example.md) shows the tests. Test:

- that the class derives from `WorkflowActivityBase<THandler>`;
- each argument's attributes (`[RequiredArgument]`, the `[Input]` and `[Output]` names, and any `[ReferenceTarget]`), because they are the registration contract;
- each input variation and each output;
- a missing or invalid input, through `AssertInvokeFailsWithoutCallingService<TInner>()`. The host may wrap failures, so it looks for `TInner` among the inner exceptions.

### Composition roots

For each root, test that every handler resolves from an execution scope holding what the base class registers for each invocation, and add a line for each new handler. Both examples show the test. Only the workflow runtime can create a `CodeActivityContext`, so the workflow root test registers an uninitialised one, which resolving a handler doesn't use.

### Infrastructure, constants and existing behaviour

- The infrastructure and `EntityExtensions` tests come with the assets. Keep them passing, and don't edit them in a feature. In `SharedSourceAssemblyTests`, list a type from each shared project.
- Pin each shared constant (custom message names, business keys) with a test, so that a change is deliberate.
- Before moving existing code, make sure tests cover its behaviour. After the move, each existing test case has a counterpart.

## Checklist

- Each test was written first and seen to fail before its code existed.
- A test supplies a second, different configuration (or set of inputs) and shows the behaviour changes.
- Missing, malformed or incomplete configuration fails with a clear message and writes nothing.
- The application service's writes are asserted by record and attributes, the do-nothing case writes nothing, and its inputs are unchanged.
- An `Update` target holds only the changed attributes, so logic that needs other values reads them from an image. A test uses a target that lacks them.
- The handler has a test for each contract failure, which calls nothing, and a test that it calls the application service once.
- The plug-in has a happy path for each registered step, a contract failure and an unexpected failure.
- The activity's argument attributes are pinned, a missing required input gives the expected failure, and each output is set.
- The composition root resolves every handler.
- Each bug kept on purpose is pinned by a test and marked with a TODO.
- After a migration, each existing test case has a counterpart.
- The new test files add no analyser warnings.
