# Infrastructure: the handler-first scaffold

This is the preferred structure for plug-ins and custom workflow activities (CWAs). Use it for new projects, and for existing projects that have adopted it or whose owners ask for it. Otherwise follow the project's own base classes, and propose adopting this as a separate, approved change (see "Changing existing code" in the skill).

Each entry point (`IPlugin` or `CodeActivity`) is declarative. Its base class creates an execution scope for each invocation, then resolves a **handler** and runs it. The handler sits beside its entry point. It checks the registration contract and calls an application service. A small container builds the handler and everything it needs, new for each invocation.

```text
CopyFieldsToRelatedRecordPlugin        plug-in head: the registered class, with no logic
  PluginBase<THandler>                 infrastructure: one execution scope per call
    CopyFieldsToRelatedRecordHandler   plug-in head: checks the step, adapts, chooses how to persist
      IRelatedRecordFieldCopier        application: the use case, with no host types
        IOrganizationService, contexts and query classes   Dataverse
```

## What to copy

The code ships as tested assets. Copy them rather than write your own.

| Asset                                                                                                                       | Copy into                                | What it is                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [Infrastructure/](../assets/Infrastructure/) and [IsExternalInit.cs](../assets/IsExternalInit.cs)                           | The Infrastructure shared project        | The container, base classes, handler contracts, identity providers, logging and step constants |
| [Dataverse/](../assets/Dataverse/)                                                                                          | The Dataverse shared project             | `EntityExtensions` (`Clone` and `GetChanges`)                                                  |
| [UnitTests/Support/](../assets/UnitTests/Support/)                                                                          | The unit test project's `Support` folder | The test base classes, simulated hosts and mock helpers                                        |
| [UnitTests/Infrastructure/](../assets/UnitTests/Infrastructure/) and [UnitTests/Dataverse/](../assets/UnitTests/Dataverse/) | The unit test project                    | 126 tests that pin the behaviour described here                                                |

- Replace the `Abc` root namespace with the project's, and keep the folders and namespaces below it. Change nothing else, because the tests pin the behaviour. A change to the infrastructure is a separate, reviewed change, never part of a feature.
- In `SharedSourceAssemblyTests`, list a type from each shared project the solution has.
- The code needs .NET Framework 4.8, `System.Activities`, `Microsoft.CrmSdk.CoreAssemblies` and `Microsoft.CrmSdk.Workflow`. It compiles with C# 7.3 or later and builds without StyleCop warnings. The tests need MSTest, FluentAssertions 7 and Moq. The project files are in [project-structure.md](project-structure.md).

## How an invocation runs

Dataverse creates an entry point once and may call it concurrently, so nothing about an invocation is stored on it. Each call does the following:

1. Creates an execution scope from the composition root.
2. Registers the services the host supplied in the scope. These are **borrowed**, so the scope never disposes them.
3. Resolves the handler, building each registered dependency new.
4. Calls the handler's `Execute()`.
5. Disposes the scope, which disposes what it built, newest first.

| Constructors can take                                                                      | Plug-in                         | CWA |
| ------------------------------------------------------------------------------------------ | ------------------------------- | --- |
| `IOrganizationService`, running as the executing user                                      | Yes                             | Yes |
| `ITracingService` and `IOrganizationServiceFactory`                                        | Yes                             | Yes |
| `IExecutionServiceProvider` (see [Identity](#identity))                                    | Yes                             | Yes |
| `IPluginExecutionContext`, and `IPluginExecution` (its `Context`, `Service` and `Tracing`) | Yes                             | No  |
| `PluginStepConfiguration` (`Unsecure` and `Secure`)                                        | Yes                             | No  |
| `ILogger` (Application Insights)                                                           | Only when Dataverse supplies it | No  |
| `CodeActivityContext` and `IWorkflowContext`                                               | No                              | Yes |
| The activity, as its concrete type                                                         | No                              | Yes |
| Anything registered in the composition root                                                | Yes                             | Yes |

### Failures

|                                   | Plug-in (`PluginBase<THandler>`)                                                                                                                               | CWA (`WorkflowActivityBase<THandler>`)               |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Traces                            | The handler's start, completion and failure                                                                                                                    | The handler's completion and failure                 |
| `InvalidPluginExecutionException` | Rethrown unchanged                                                                                                                                             | Rethrown unchanged                                   |
| Any other exception               | Wrapped in `InvalidPluginExecutionException` ("The plug-in could not complete. See the plug-in trace log for details."), with the cause as its inner exception | Rethrown unchanged                                   |
| A host service is missing         | `InvalidOperationException`, wrapped, before the handler runs                                                                                                  | `InvalidOperationException`, before the handler runs |

- Throw `InvalidPluginExecutionException` for a failure the user should see, with a message that says what to do. Throw anything else for a fault, and the trace log holds the detail.
- An execution failure always wins. Cleanup is still attempted, and a cleanup failure is traced without replacing the execution failure. If execution succeeded, a cleanup failure fails the invocation. Several cleanup failures aggregate into an `AggregateException`. A failure while tracing never replaces either.
- The workflow runtime may unwrap an aggregate, so a CWA's caller can see only its first inner exception. Don't rely on its shape.

## The container

`PluginContainer` is deliberately small.

- **Root.** Create it with `new PluginContainer()`, then call `Register<TService, TImplementation>()` or `Register<TImplementation>()`. Each implementation must be a closed, concrete class with exactly one public constructor. Registering a type twice throws.
- **Scope.** `root.CreateExecutionScope()` freezes the root and copies its registrations into a new scope. Registering on a frozen root throws. Only a scope accepts instances: `Register<TService>(instance)` borrows the instance and exposes it as exactly `TService`.
- **Resolve** builds a new instance of every registered type each time, even when one graph needs a type twice. Only borrowed instances are shared, so each service that takes a context gets its own.
- A missing registration, a cycle or a second public constructor fails when the handler is resolved, at the first invocation. The composition root tests catch it before then (see [unit-testing.md](unit-testing.md)).
- Calls are lock-guarded, so concurrent invocations share the root safely.

## Composition roots

Each head has one `internal static` composition root, built once per loaded assembly. This is the plug-in head's, from the [plug-in example](plugin-example.md):

```csharp
namespace Abc.Plugins
{
    using System;
    using Abc.Application.FieldCopying;
    using Abc.Dataverse.Contexts;
    using Abc.Dataverse.Model;
    using Abc.Dataverse.Queries;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Logging;
    using Abc.Plugins.FieldCopying;

    /// <summary>The registrations that every plug-in in this assembly resolves its handler from.</summary>
    internal static class PluginCompositionRoot
    {
        private static readonly Lazy<PluginContainer> Container = new Lazy<PluginContainer>(BuildRoot);

        /// <summary>Gets the root, built once per loaded assembly and frozen when the first invocation uses it.</summary>
        public static PluginContainer Root => Container.Value;

        // Registrations only: the root outlives every invocation, so it must never hold an invocation's services.
        private static PluginContainer BuildRoot()
        {
            var root = new PluginContainer();

            root.Register<ILogWriter, TracingLogWriter>();

            // Data access: each context and query class an application service takes, created per invocation.
            root.Register<IAbcContextFactory, AbcContextFactory>();
            root.Register<AbcContext>();
            root.Register<CaseQueries>();

            root.Register<IRelatedRecordFieldCopier, RelatedRecordFieldCopier>();
            root.Register<CopyFieldsToRelatedRecordHandler>();

            return root;
        }
    }
}
```

- **Registrations only.** Register each handler, application service, context and query class the handlers need. Adding an entry point adds registrations, not another root.
- Never register host services, because each scope borrows them. Never register an activity, because it registers itself.
- Only the base classes resolve, and only from a scope. The root holds no invocation's services, so resolving from it fails.
- Never cache a handler, scope, context or service in a field or static. Never inject `PluginContainer` or `IServiceProvider` into a handler or service. Dependencies arrive through constructors.

Entry points pass their head's root to the base class:

- A plug-in derives from `PluginBase<THandler>`. Its public constructor passes `PluginCompositionRoot.Root`. If its steps have configuration, the constructor takes `(string unsecureConfiguration, string secureConfiguration)` and passes both on.
- An activity derives from `WorkflowActivityBase<THandler>`. Its public parameterless constructor passes `WorkflowCompositionRoot.Root`. It declares its arguments and implements `RegisterActivity` as `scope.Register<ThisActivity>(this);`. Registering it as `CodeActivity` wouldn't satisfy a handler that takes the concrete type.

## Identity

| Ask for                                                                           | Plug-in                                                 | CWA                                                                                 |
| --------------------------------------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `IOrganizationService`, `GetExecutingUserService()` or `CreateForExecutingUser()` | The user the step runs as (`UserId`)                    | The user the process runs as (`UserId`)                                             |
| `GetInitiatingUserService()` or `CreateForInitiatingUser()`                       | The user who started the operation (`InitiatingUserId`) | That user only when it's also the executing user, otherwise `NotSupportedException` |
| `GetSystemService()` or `CreateForSystem()`                                       | SYSTEM                                                  | Always `NotSupportedException`                                                      |

- An unqualified `IOrganizationService` or context means the executing user. Never rebind or replace it.
- A component that needs another identity takes `IExecutionServiceProvider` or the context factory and asks for that identity by name. SYSTEM needs a reviewed reason recorded in the design. Never retry an access-denied call as another user.
- The workflow host can't switch identity, so the workflow provider fails rather than return the wrong user.
- The caller owns each context the factory creates. Dispose it with `using` within the invocation, and never share it across identities. See [data-access.md](data-access.md).

## Logging

- Log through `ILogWriter.Log(Severity, tag, message)`, and register `TracingLogWriter` in each root. It writes `<UTC time>: <tag>: <severity>: <message>` to the trace log, passing the message as a format argument so braces in it are safe. The severities are `Verbose`, `Info`, `Warning` and `Error`.
- The base classes trace each handler's start (plug-ins only), completion and failure. Handlers and services log their decisions, especially ones that lead to doing nothing.
- `ILogger` (Application Insights) is registered for plug-ins only, and only when Dataverse supplies it. A handler that requires it fails to resolve without it. Only a plug-in handler may take it, and only where the integration is on. Application services never take it.

## Step helpers

- These constant classes name what handlers check:
  - `PluginMessages`: `Create`, `Update`, `Delete` and `SetState`.
  - `PluginStages`: `PreValidation`, `PreOperation` and `PostOperation`.
  - `PluginModes`: `Synchronous` and `Asynchronous`.
  - `PluginInputParameters`: `Target` and `EntityMoniker`.

  Add a constant to them, with a test that pins its value, rather than repeat a literal.
- `PluginStepConfiguration` holds the strings Dataverse passed to the plug-in's constructor. A handler that needs configuration takes it and parses `Unsecure` (see [standards.md](standards.md)). Never log `Secure`.

## Entity helpers

`EntityExtensions` sits in the Dataverse layer:

- `Clone<T>()` copies an entity, keeping its type, logical name and ID. Business logic clones its input rather than mutate it. The copy is shallow, so replace a mutable value rather than change it.
- `GetChanges(original)` returns a new entity that holds only the new or different values, ready for an `Update`. Values are compared with `object.Equals`. Strings (case-sensitively), `Money`, `OptionSetValue`, `EntityReference` (the same record) and `DateTime` compare by value. Before relying on another type, check how it compares. For example, `EntityCollection` may compare by reference.

## Test support

The `Support` assets simulate both hosts, so you can test an entry point end to end, and a plug-in handler on its own, without Dataverse. See [unit-testing.md](unit-testing.md).
