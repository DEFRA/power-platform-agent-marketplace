# Plug-in and custom workflow activity standards

Applies to plug-ins, custom workflow activities (CWAs) and the code they call. Where these rules are silent, follow the project's neighbouring code. For the stack and versions see [stack.md](../../power-platform-standards/references/stack.md). The structure that implements them is in [infrastructure.md](infrastructure.md).

## Design

- **Layers.** Entry points and their handlers live in the plug-in and workflow projects (the heads). Application services, data access and infrastructure live in shared projects (see [project-structure.md](project-structure.md)).
- **Declarative entry points.** A plug-in or activity class holds no logic. A plug-in passes its root and step configuration to `PluginBase<THandler>`. An activity declares its arguments and registers itself.
- **Handlers adapt.** A handler sits beside its entry point, in the same namespace. It does four things:
  - checks the registration contract (message, table, stage, mode, and images or arguments);
  - takes what the host supplies;
  - makes one or two coarse calls to an application service;
  - applies the result as the host needs, for example by copying values onto the `Target` or setting outputs.

  It chooses *how* the result is persisted, never *what* the result is. It holds no business rules, builds no queries, and doesn't sequence a read, a decision and a write.
- **Application services own the use case.** Each service is shaped by a use case (`IRelatedRecordFieldCopier`), not a catch-all for a table. It never takes `IPluginExecutionContext`, `CodeActivityContext`, `IWorkflowContext`, a handler or any other host type. So the same service runs from a plug-in or a CWA, and its tests need no host. It may take query classes, `IOrganizationService` or the context directly (see [data-access.md](data-access.md)).
- **Persistence is explicit.** A method's name and documentation say whether it writes. A `Get…` method returns a result and writes nothing. A method that writes says what it updates, and its tests prove it.
- **Never mutate an input.** Business logic clones an entity it's given, changes the clone, and returns it. The pipeline `Target` is a shared, mutable reference. Prefer the entity the host already holds over an ID that forces a re-read.
- **Single responsibility.** A class has one reason to change. Split anything you describe with "and".
- **Open/closed.** Add behaviour with configuration, data or a new small class, not by editing a working one. Replace `if` and `switch` chains on a key with a lookup that data chooses. Don't add a flag or mode for each new requirement.
- **Liskov and interface segregation.** An implementation honours its abstraction's contract. Depend on the narrowest abstraction you need: a small interface or a value, not a whole service or entity.
- **Dependency inversion and DRY.** Every class receives its dependencies through its one public constructor, and the container builds the graph. Never create a dependency with `new`, read it from a static, or ask the container for it. Extend an existing generic class before writing a new one.
- **Capability naming.** Name every class, file, namespace, step, argument and activity for the capability, not the first use case: `CopyFieldsToRelatedRecord`, not `CopyInspectionOutcomeToCase`. Name a plug-in class for the utility it provides, not for a message, stage or table. One plug-in class can serve several steps. When a use-case-named class must stay, see "Changing existing code" in the skill.
- **No speculative generality.** Generalise to the capability the requirement plainly implies, and no further. Add no extension point that nothing uses.

## Configuration and data

Anything that varies by table, column, key, threshold, message or environment is configuration, not code. Hard-code only what is structural.

| Mechanism                   | Use it for                                                                                                                   |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Step unsecure configuration | Per-step settings, visible to anyone who can read the step                                                                   |
| Step secure configuration   | Secrets only. Never log it                                                                                                   |
| CWA inputs                  | Anything a maker should change per process (see [workflow-activity-contract.md](workflow-activity-contract.md))              |
| Data                        | Reference or seed data the logic reads. Query it through a query class or the context (see [data-access.md](data-access.md)) |

- Parse step configuration with `DataContractJsonSerializer` into a `[DataContract]` class. It is part of .NET Framework, so it adds no dependency to the assembly. The handler takes `PluginStepConfiguration` and passes its `Unsecure` string to the parser.
- **Parse and validate in one place** (a static `Parse` method on the settings class). Fail with a clear message that says what to supply, and write nothing. Cover it with tests.
- A table, column or key supplied by configuration or an input is handled late-bound (`Entity`, `EntityReference.LogicalName`), validated, and fails clearly if wrong.

## Logging

Observability is always present. Log through `ILogWriter` (or the project's own logging abstraction), with enough context to diagnose a failure from the plug-in trace log alone. The base classes trace when a handler completes or fails, and the plug-in base also traces when it starts. Each plug-in trace log row records the message, table, depth and step, so don't repeat those. Log:

- each decision that leads to doing nothing ("no value in lookup, nothing to copy");
- the values a failure needs to be diagnosed.

Never log secrets, secure configuration or personal data. `ITracingService.Trace(string, params object[])` treats its first argument as a format string. Pass user data as an argument (`Trace("{0}", message)`), not inside the format, or a `{` in it throws `FormatException`. `TracingLogWriter` already does this.

## Platform constraints

- **.NET Framework 4.8 and C# 13.** Language features that need runtime types missing from .NET Framework aren't available, for example default interface members, `required` members and `Index` and `Range`. `init` accessors and records work because [IsExternalInit.cs](../assets/IsExternalInit.cs) is in the Infrastructure shared project. Avoid records that hold secure configuration, since a record's `ToString` prints every property.
- **No `async`, `Task`, parallel or threading code** in plug-ins, activities or anything they call. They run synchronously within a time limit.
- **Stateless entry points.** Dataverse caches plug-in and activity instances and invokes them concurrently. Hold no per-invocation state in their fields, in a composition root or in a static. Handlers and services are created for each invocation, so their fields can hold that invocation's dependencies.
- **Run as the executing user.** Don't change identity or elevate privileges, add retries, wrap transactions or defer writes without a reviewed design (see [infrastructure.md](infrastructure.md#identity)). Transaction control stays with Dataverse.
- A plug-in assembly is registered on its own, so any dependency beyond the platform SDK must be merged into it or shipped in a plug-in package. Plug-in packages don't support CWAs, so code shared between assemblies goes in shared projects instead (see [project-structure.md](project-structure.md)). Keep dependencies few and agree any new one with the human.

## Data access

The rules and examples are in [data-access.md](data-access.md). In short:

- Use the early-bound model for names the code fixes at compile time: `<Entity>.EntityLogicalName`, `<Entity>.Fields.<Name>`, the generated option set enums. Never use string literals or numbers for them. Casing differs between generated tables, so look names up (see `dataverse-schema`) rather than guess. Never edit the generated model.
- Read only the columns you need, by projecting in LINQ or with a `ColumnSet`. Prefer early-bound LINQ, then `QueryExpression`. Use FetchXML only when they can't express the query, and say why in a comment.
- Build an `Update` that holds only the attributes that change (`GetChanges`), and send nothing if nothing changed.
- Put shared names (custom message names, business keys) in a constants class in the Application layer, not in private copies in several classes.

## Errors

- Throw `InvalidPluginExecutionException` for failures a user should see, with a message that says what to do. It rolls back the transaction.
- The base classes trace every failure, and the plug-in base wraps unexpected ones (see [infrastructure.md](infrastructure.md#failures)). Don't catch an exception just to log it and rethrow.
- Never add an empty `catch`. Don't swallow an exception unless the design says the operation must not be blocked.

## Style

- Follow the project's analysers and layout. New and changed code adds no warnings, and no suppressions (`#pragma warning disable`, `[SuppressMessage]`, `NoWarn`) without approval.
- Comment only what needs clarifying. Write comments and documentation in British English, except where an analyser mandates wording.
