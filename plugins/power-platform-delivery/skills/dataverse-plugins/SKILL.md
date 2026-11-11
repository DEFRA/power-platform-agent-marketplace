---
name: dataverse-plugins
description: Designs, writes and reviews Dataverse plug-ins and custom workflow activities, with the services and tests behind them. Covers when code is justified over low-code, capability naming, the handler-first dependency injection scaffold, step configuration, data access, test-first development and the registration hand-off. Use for any request to add or change a plug-in or custom workflow activity.
---

# Dataverse plug-ins and custom workflow activities

Intended for `developer` (and `developer-worker` on an approved brief), but usable by anyone. Load `power-platform-standards` first. This skill is the procedure. The rules and code live in `references/`, loaded when a step needs them.

| Reference                                                                 | Load it when                                                                                                                   |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| [standards.md](references/standards.md)                                   | Designing or reviewing any plug-in or custom workflow activity (CWA)                                                           |
| [infrastructure.md](references/infrastructure.md)                         | Writing or reviewing an entry point, handler or composition root, or setting up the scaffold                                   |
| [data-access.md](references/data-access.md)                               | Reading or writing Dataverse data: contexts, query classes and LINQ                                                            |
| [project-structure.md](references/project-structure.md)                   | Adding files or projects, setting up a new project, or building and testing (shared projects and the `UnitTest` configuration) |
| [plugin-contract.md](references/plugin-contract.md)                       | Defining a plug-in step, writing its registration hand-off, or checking pitfalls                                               |
| [workflow-activity-contract.md](references/workflow-activity-contract.md) | Defining a CWA's inputs and outputs, writing its hand-off, or checking pitfalls                                                |
| [unit-testing.md](references/unit-testing.md)                             | Writing or reviewing the tests                                                                                                 |
| [plugin-example.md](references/plugin-example.md)                         | You want a worked, tested plug-in to adapt                                                                                     |
| [workflow-activity-example.md](references/workflow-activity-example.md)   | You want a worked, tested CWA to adapt                                                                                         |

## When code is justified

Low-code comes first. Business processes belong in workflows, actions, business process flows and cloud flows. Code needs a reason.

- **Plug-in.** Use one only when a declarative component can't do the job. For example: it must change the behaviour of a managed action, run on a message that workflows and flows don't support, or run inside the transaction (pre-operation or post-operation) where a real-time workflow can't. Plug-in steps are rarely right. They lack the scoping of workflows and the inputs and outputs of actions.
- **CWA.** Use one when a workflow or action needs a capability the platform lacks, such as a calculation, a lookup that conditions can't express, or a call that needs code. It must be generic and granular, so makers can reuse it by changing its inputs.

If the requirement is really a business process, say so in the design and propose the declarative alternative. Don't write code until the user decides. Low-code build stays with the human developer.

## Principles in one line each

Detail and the reasons are in [standards.md](references/standards.md).

- **Name it for the capability**, not the first use case. The first requirement is one row of configuration.
- **Handler-first, with dependency injection.** The plug-in or activity is declarative. Its base class creates an execution scope for each invocation and resolves a handler from the head's composition root. The handler checks the registration contract and calls an application service. See [infrastructure.md](references/infrastructure.md).
- **Host-independent application services.** They hold the logic and never see `IPluginExecutionContext`, `CodeActivityContext` or any other host type. Data access goes through contexts and query classes (see [data-access.md](references/data-access.md)).
- **What varies is configuration.** Step configuration (parsed with `DataContractJsonSerializer` into a `[DataContract]` class) or CWA inputs. Never constants.
- **SOLID and DRY, with constructor injection.** Each class has one job and depends on abstractions. Register it in the composition root rather than constructing it by hand.
- **Logging is always present**, through `ILogWriter` or the project's own logger.
- **Stateless and synchronous.** No `async`, `Task` or threading.
- **Shared projects for shared code.** The infrastructure, the Dataverse layer and the application services live in shared projects, because plug-in packages don't support CWAs. Unit tests build in a `UnitTest` configuration against one shared-code assembly. See [project-structure.md](references/project-structure.md).
- **Test first**, including a test with a second, different configuration.
- **Stack:** .NET Framework 4.8 and C# 13. See [stack.md](../power-platform-standards/references/stack.md).

## Procedure

1. **Discover the project.** Find the plug-in and workflow projects, the shared projects and shared-code assembly (see [project-structure.md](references/project-structure.md)), the base classes, logger and composition roots, the early-bound model and contexts, the test project and its frameworks, and neighbouring plug-ins to copy conventions from. Confirm what you found (see [project-facts.md](../power-platform-standards/references/project-facts.md)).
   - If the project uses the scaffold (`PluginBase<THandler>`, `WorkflowActivityBase<THandler>` and composition roots), follow [infrastructure.md](references/infrastructure.md).
   - If the project is new, propose setting up the scaffold from the assets, for the human to approve.
   - If it has its own base classes, follow them and its conventions. Propose adopting the scaffold only as a separate, approved change (see "Changing existing code").
2. **Generalise first.** Restate the requirement as the general capability it is an instance of, and write down the proposed name. Look for an existing generic class to extend through configuration. Ask: "If a similar requirement arrived next month, would this need only a new step (or new inputs) and not new code?"
3. **Capture the contract.** Use the table in [plugin-contract.md](references/plugin-contract.md) or [workflow-activity-contract.md](references/workflow-activity-contract.md). Agree each item with the user, and ask for any that are missing.
4. **Check the model.** Every table and column the code names at compile time must exist in the early-bound model. If one is missing, stop and ask the human to regenerate it (see `dataverse-schema`). Don't work around the gap with late-bound names. Names that arrive through configuration or inputs are late-bound by design.
5. **Propose the design and wait for explicit approval.** State:
   - the capability and name, and the contract;
   - what is configuration and where it lives;
   - the settings, application service and its interface, handler and entry point, each with a single responsibility, and the composition root registrations;
   - the ordered test list, simplest first, including the second-configuration test;
   - what the human must register or change in their development environment;
   - how the design meets each principle above.
6. **Take a warnings baseline** before the first C# edit, using `dotnet-build-verification`.
7. **Build test-first, one behaviour at a time.** Red, green, refactor. Order: the settings, then the application service (in the Application shared project), then the handler, then the entry point with its composition root registration. Follow [unit-testing.md](references/unit-testing.md), and adapt the [plug-in](references/plugin-example.md) or [workflow activity](references/workflow-activity-example.md) example.
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

### Moving code to the scaffold

Do this only as an approved change. Don't move code just to complete the scaffold.

- Move one entry point at a time, vertically: its handler, application service, data access and tests together. Update the `.projitems` files in the same change.
- Pin the behaviour with tests before the move. Each existing test case keeps a counterpart.
- Keep the entry point's class name, namespace and registration, so that nothing needs registering again.
- Raise a suspected bug rather than fix it. Preserve it, pin it with a test, and mark it `// TODO: <issue>. This should be investigated, but is preserved by the refactoring.`
- Fix analyser warnings in the moved code, without suppressions.
