# Plug-in and custom workflow activity standards

Applies to plug-ins, custom workflow activities (CWAs) and the code they call. Where these rules are silent, follow the project's neighbouring code. For the stack and versions see [stack.md](../../power-platform-standards/references/stack.md).

## Design

- **Single responsibility.** An entry point adapts the platform and calls one business logic class. A business logic class has one reason to change. Split anything you describe with "and".
- **Thin entry points.** A plug-in reads the execution context (target, images, inputs and step configuration), calls business logic, and applies the result. A CWA reads its inputs, calls business logic, and sets its outputs.
- **Host-independent logic.** Business logic classes have no dependency on `IPluginExecutionContext`, `CodeActivityContext`, `IWorkflowContext` or any other plug-in or CWA type. The same class can then run from any plug-in, CWA or other host, and tests need no host.
- **Open/closed.** Add behaviour with configuration, data or a new small class, not by editing a working one. Replace `if` and `switch` chains on a key with a lookup that data chooses. Don't add a flag or mode for each new requirement.
- **Liskov and interface segregation.** An implementation honours its abstraction's contract. Depend on the narrowest abstraction you need: a small interface or a value, not a whole service or entity.
- **Dependency inversion and DRY.** Business logic receives its dependencies (organisation service, logger, repositories) through its constructor. It never creates them with `new` and never reads them from a static. **A DI container isn't required.** The entry point is the composition point and builds the object graph by hand. Extend an existing generic class before writing a new one.
- **Capability naming.** Name every class, file, namespace, step, argument and activity for the capability, not the first use case: `CopyFieldsToRelatedRecord`, not `CopyInspectionOutcomeToCase`. When a use-case-named class must stay, see "Changing existing code" in the skill.
- **No speculative generality.** Generalise to the capability the requirement plainly implies, and no further. Add no extension point that nothing uses.

## Configuration and data

Anything that varies by table, column, key, threshold, message or environment is configuration, not code. Hard-code only what is structural.

| Mechanism | Use it for |
| --- | --- |
| Step unsecure configuration | Per-step settings, visible to anyone who can read the step |
| Step secure configuration | Secrets only. Never log it |
| CWA inputs | Anything a maker should change per process (see [workflow-activity-contract.md](workflow-activity-contract.md)) |
| Data | Reference or seed data the logic reads. Query it through a repository abstraction |

- Parse step configuration with `DataContractJsonSerializer` into a `[DataContract]` class. It is part of .NET Framework, so it adds no dependency to the assembly.
- **Parse and validate in one place** (a static `Parse` method on the settings class). Fail with a clear message that says what to supply, and write nothing. Cover it with tests.
- A table, column or key supplied by configuration or an input is handled late-bound (`Entity`, `EntityReference.LogicalName`), validated, and fails clearly if wrong.

## Logging

Observability is always present. Trace through the project's logging abstraction, with enough context to diagnose a failure from the plug-in trace log alone:

- entry (message, table, stage and depth for a plug-in);
- each decision that leads to doing nothing ("no value in lookup, nothing to copy");
- failures, with the exception.

Never log secrets, secure configuration or personal data. `ITracingService.Trace(string, params object[])` treats its first argument as a format string. Pass user data as an argument (`Trace("{0}", message)`), not inside the format, or a `{` in it throws `FormatException`.

## Platform constraints

- **.NET Framework 4.8 and C# 13.** Language features that need runtime types missing from .NET Framework aren't available, for example default interface members, `required` members and `Index` and `Range`. `init` accessors and records work once [IsExternalInit.cs](../assets/IsExternalInit.cs) is in the project. Avoid records that hold secure configuration, since a record's `ToString` prints every property.
- **No `async`, `Task`, parallel or threading code** in plug-ins, activities or anything they call. They run synchronously within a time limit.
- **Stateless.** Instances are cached and invoked concurrently. Hold no per-invocation state in fields or statics. Immutable configuration set in the constructor is fine.
- **Don't change identity or elevate privileges**, add retries, wrap transactions or defer writes without a reviewed design. Transaction control stays with Dataverse.
- A plug-in assembly is registered on its own, so any dependency beyond the platform SDK must be merged into it or shipped in a plug-in package. Keep dependencies few and agree any new one with the human.

## Data access

- Use the early-bound model for names the code fixes at compile time: `<Entity>.EntityLogicalName`, `<Entity>.Fields.<Name>`, the generated option set enums. Never use string literals or numbers for them. Casing varies between generated tables, so look names up (see `dataverse-schema`) rather than guess.
- Retrieve only the columns you need (`ColumnSet` or a projection). Prefer `QueryExpression` and LINQ. Use FetchXML only when they can't express the query, and say why in a comment.
- Never mutate an entity you were given unless that is the method's documented purpose. Build a new entity for an `Update` that holds only the attributes that change.
- Put shared names (custom message names, business keys) in a constants class, not in private copies in several classes.

## Errors

- Throw `InvalidPluginExecutionException` for failures a user should see, with a message that says what to do. It rolls back the transaction.
- Handle and log errors the way the surrounding code does. Never add an empty `catch`. Don't swallow an exception unless the design says the operation must not be blocked.

## Style

- Follow the project's analysers and layout. New and changed code adds no warnings, and no suppressions (`#pragma warning disable`, `[SuppressMessage]`, `NoWarn`) without approval.
- Comment only what needs clarifying. Write comments and documentation in British English, except where an analyser mandates wording.
