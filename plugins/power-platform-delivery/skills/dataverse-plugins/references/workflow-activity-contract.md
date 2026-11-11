# Custom workflow activity contract and hand-off

Load this when defining a custom workflow activity (CWA). A worked example is in [workflow-activity-example.md](workflow-activity-example.md).

## Design

- **Name it for the capability and expose what varies as inputs.** A CWA's inputs are its configuration, and makers change them without a release: `TrimTextFields` with a list of attribute names, not `TrimApplicantName`.
- **One activity, one job.** Prefer several small activities that makers combine to one large one with many modes. Add a new activity, or a new input with a safe default, rather than a flag that changes what an existing one does.
- **A declarative activity.** The activity class declares its arguments and registers itself in `RegisterActivity`. Its handler reads the inputs, calls an application service, and sets the outputs (see [infrastructure.md](infrastructure.md)).
- **An activity for any table acts on the primary record** of the process that runs it (`IWorkflowContext.PrimaryEntityName` and `PrimaryEntityId`). A lookup input must name one table, so it can't make an activity generic.

## Contract

| Item                        | Decide                                                                                                                            |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Capability and name         | The general capability and the activity name that describes it                                                                    |
| Inputs                      | Name, type, and whether required. For a lookup, its table; for a choice, its table and column. Everything that varies is an input |
| Configuration beyond inputs | Anything not per process, where it lives, its format and how a bad value fails                                                    |
| Outputs                     | Name and type, and what a workflow or action reads from them                                                                      |
| Effects                     | The record it acts on (the primary record or a lookup input), the records it reads and writes, and whether it writes at all       |
| Failure                     | Throw (fails the workflow and shows a message) or log and continue                                                                |
| Display text                | Name, friendly name, description and group, which makers see. Describe the capability, not the first use                          |

## Registration hand-off

A CWA is registered with its plug-in assembly, and its arguments are read from the assembly. Registering it, and any workflow or action that uses it, is low-code build and stays with the human. Tell the user, in the report:

- the activity's name, friendly name, description and group as makers should see them;
- that new or changed arguments appear in the process designer only after the assembly is updated in their development environment, and that any workflow or action using it is changed there and reaches the repository when the solution metadata is synchronised;
- that changing or removing an argument breaks processes that use it. Prefer adding an optional input, and flag a breaking change before making it.

## Pitfalls

- Activities are cached and shared across executions. Keep them stateless: the handler reads arguments from the `CodeActivityContext` on each call, and nothing is kept in a field of the activity.
- Read an argument with `Get(context)` and write an output with `Set(context, value)`. Don't read an `InArgument` directly.
- Every `EntityReference` argument needs `[ReferenceTarget("<table>")]`, and every `OptionSetValue` argument needs `[AttributeTarget("<table>", "<column>")]`.
- Give each argument a clear display name: it is what makers see. Mark each mandatory input `[RequiredArgument]`.
- The organisation service runs as the workflow's user (`IWorkflowContext.UserId`). Don't change the identity (see [infrastructure.md](infrastructure.md#identity)).
- Changing an argument's name or type is a breaking change for processes that use it.
- Don't hard-code a table, attribute, key or threshold that a maker might want to change. Make it an input.
- Don't add a boolean input that switches the activity into a different job. Split it into two activities.
