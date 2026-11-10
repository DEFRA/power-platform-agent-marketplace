---
name: dataverse-plugins
description: Designs, writes and reviews Dataverse plug-ins and custom workflow activities, plus the business logic and unit tests behind them. Covers when code is justified over low-code, capability naming, thin classes, host-independent logic, step configuration, logging, test-first development and the registration hand-off. Use for any request that adds or changes a plug-in or custom workflow activity.
---

# Dataverse plug-ins and custom workflow activities

Intended for `developer` (and `developer-worker` on an approved brief), but usable by anyone. Load `power-platform-standards` first. This skill is the procedure. The rules and code live in `references/`, loaded when a step needs them.

| Reference | Load it when |
| --- | --- |
| [standards.md](references/standards.md) | Designing or reviewing any plug-in or custom workflow activity (CWA) |
| [project-structure.md](references/project-structure.md) | Adding files or projects, setting up a new project, or building and testing (shared projects and the `UnitTest` configuration) |
| [plugin-contract.md](references/plugin-contract.md) | Defining a plug-in step, writing its registration hand-off, or checking pitfalls |
| [workflow-activity-contract.md](references/workflow-activity-contract.md) | Defining a CWA's inputs and outputs, writing its hand-off, or checking pitfalls |
| [unit-testing.md](references/unit-testing.md) | Writing or reviewing the tests |
| [base-classes.md](references/base-classes.md) | The project has no plug-in or CWA base class or logger |
| [plugin-example.md](references/plugin-example.md) | You want a worked, tested plug-in to adapt |
| [workflow-activity-example.md](references/workflow-activity-example.md) | You want a worked, tested CWA to adapt |

## When code is justified

Low-code comes first. Business processes belong in workflows, actions, business process flows and cloud flows. Code needs a reason.

- **Plug-in.** Use one only when a declarative component can't do the job. For example: it must change the behaviour of a managed action, run on a message that workflows and flows don't support, or run inside the transaction (pre-operation or post-operation) where a real-time workflow can't. Plug-in steps are rarely right. They lack the scoping of workflows and the inputs and outputs of actions.
- **CWA.** Use one when a workflow or action needs a capability the platform lacks, such as a calculation, a lookup that conditions can't express, or a call that needs code. It must be generic and granular, so makers can reuse it by changing its inputs.

If the requirement is really a business process, say so in the design and propose the declarative alternative. Don't write code until the user decides. Low-code build stays with the human developer.

## Principles in one line each

Detail and the reasons are in [standards.md](references/standards.md).

- **Name it for the capability**, not the first use case. The first requirement is one row of configuration.
- **Thin entry point, host-independent logic.** The plug-in or activity reads the context, calls a business logic class, and applies the result. The logic class never sees `IPluginExecutionContext`, `CodeActivityContext` or any other host type.
- **What varies is configuration.** Step configuration (parsed with `DataContractJsonSerializer` into a `[DataContract]` class) or CWA inputs. Never constants.
- **SOLID and DRY, with constructor injection.** No DI container is required. Compose by hand in the entry point.
- **Logging is always present**, through the project's logger.
- **Stateless and synchronous.** No `async`, `Task` or threading.
- **Shared projects for shared code.** Business logic, the model and queries live in shared projects, because plug-in packages don't support CWAs. Unit tests build in a `UnitTest` configuration against one shared-code assembly. See [project-structure.md](references/project-structure.md).
- **Test first**, including a test with a second, different configuration.
- **Stack:** .NET Framework 4.8 and C# 13. See [stack.md](../power-platform-standards/references/stack.md).

## Procedure

1. **Discover the project.** Find the plug-in and workflow projects, the shared projects and shared-code assembly (see [project-structure.md](references/project-structure.md)), any existing `IPlugin` and `CodeActivity` base classes and the logger, the early-bound model, the test project and its frameworks, and neighbouring plug-ins to copy conventions from. Confirm what you found (see [project-facts.md](../power-platform-standards/references/project-facts.md)). The project's own classes and conventions win. If it has no base class or logger, propose the minimal ones in [base-classes.md](references/base-classes.md) for the human to approve.
2. **Generalise first.** Restate the requirement as the general capability it is an instance of, and write down the proposed name. Look for an existing generic class to extend through configuration. Ask: "If a similar requirement arrived next month, would this need only a new step (or new inputs) and not new code?"
3. **Capture the contract.** Use the table in [plugin-contract.md](references/plugin-contract.md) or [workflow-activity-contract.md](references/workflow-activity-contract.md). Agree each item with the user, and ask for any that are missing.
4. **Check the model.** Every table and column the code names at compile time must exist in the early-bound model. If one is missing, stop and ask the human to regenerate it (see `dataverse-schema`). Don't work around the gap with late-bound names. Names that arrive through configuration or inputs are late-bound by design.
5. **Propose the design and wait for explicit approval.** State:
   - the capability and name, and the contract;
   - what is configuration and where it lives;
   - the classes, each with a single responsibility, and their abstractions;
   - the ordered test list, simplest first, including the second-configuration test;
   - what the human must register or change in their development environment;
   - how the design meets each principle above.
6. **Take a warnings baseline** before the first C# edit, using `dotnet-build-verification`.
7. **Build test-first, one behaviour at a time.** Red, green, refactor. Order: configuration parsing, then the business logic class (in the business logic shared project), then the thin entry point. If the code uses `init` or records, add [IsExternalInit.cs](assets/IsExternalInit.cs) to the business logic shared project once. Follow [unit-testing.md](references/unit-testing.md).
8. **Verify.** Run the full build, test and warnings gate from `dotnet-build-verification`: unit tests in the `UnitTest` configuration, and the plug-in and workflow projects in a normal configuration. Tick the checklist in [unit-testing.md](references/unit-testing.md). Work isn't done until the gate passes.
9. **Report and hand off.**
   - Say how the design meets the principles.
   - Give the configuration to supply and the registration hand-off (it's in the contract reference). The human registers steps and assemblies in the development environment. Never hand-write step XML.
   - Code outside the synced solution metadata needs a `+semver(<solution-unique-name>): <major|minor|patch>` line in the commit body (see `commit-and-pull-request`).

## Changing existing code

- Existing behaviour is frozen unless the user approves a change. That covers outputs, writes and their timing, exceptions and their messages, and catch-and-continue behaviour.
- Make the smallest change that delivers the request. Don't fix unrelated bugs or add guards the request doesn't ask for. Flag them in the report instead.
- When a use-case-named class must stay because registered steps refer to it, add the generic class and make the old one a thin adapter that supplies its configuration.
- Add no analyser warnings and no suppressions without approval.
