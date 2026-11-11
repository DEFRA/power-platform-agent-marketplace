# Plug-in contract and hand-off

Load this when defining a plug-in step. A worked example is in [plugin-example.md](plugin-example.md).

## Step contract

Agree each item with the user, and ask for any that are missing.

| Item                 | Decide                                                                                                                                     |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Capability and name  | The general capability, and the plug-in name that describes it                                                                             |
| Table                | Logical name, and whether the early-bound model already has it                                                                             |
| Message              | `Create`, `Update`, `Delete`, a custom action name and so on                                                                               |
| Stage and mode       | Pre-validation, pre-operation or post-operation; synchronous or asynchronous                                                               |
| Filtering attributes | The attributes that trigger an `Update` step. Don't leave them empty without a reason                                                      |
| Images               | Pre or post image, its name, and only the attributes the logic reads. The handler declares the name as a constant, such as `PostImageName` |
| Configuration        | What varies, its format (JSON for the `[DataContract]` class, read from `PluginStepConfiguration`), and how bad values fail                |
| Behaviour            | Inputs, outputs, writes, and what must not happen                                                                                          |
| Failure              | Throw (rolls back the transaction) or log and continue, and the user-facing message                                                        |
| Recursion            | Whether the plug-in writes to its own table, and how it avoids a loop                                                                      |

Keep step scope narrow, and avoid organisation-wide steps on out-of-the-box messages and tables (see `power-platform-standards`).

The handler checks this contract on every invocation: the message, the stage, the mode where it matters, the `Target`, each image it needs, and the table when the plug-in is for one table. If the registration doesn't match, it throws `InvalidOperationException` before reading or writing anything, and the base class reports the failure to the user (see [infrastructure.md](infrastructure.md#failures)).

## Registration hand-off

The step is solution metadata, and registering it is low-code build, so it stays with the human. No registration attributes or step XML go in the code. Tell the user, in the report:

- the message, primary table, stage, mode, filtering attributes, execution order, run-as user and images to register, matching the design. Each image's name must match the handler's constant;
- the exact unsecure configuration to paste into the step, and its format. A second use of the same capability is another step with its own configuration, never another plug-in;
- that they register the step in their development environment against the plug-in assembly, and that it reaches the repository when the solution metadata is synchronised.

## Pitfalls

- A pre-operation change to the `Target` is saved with the operation. A post-operation step needs an explicit `Update`.
- An `Update` on the same table can trigger the plug-in again. Constrain the filtering attributes and check `Depth` where a loop is possible.
- On `Create`, the `Target` holds only the attributes that were supplied. On `Update`, it holds only the changed ones, so read anything else from a pre-image.
- A lookup set through `@odata.bind` has no `Name` on its `EntityReference`. Retrieve the record if you need the name.
- Compare message names without regard to case, and take them from `PluginMessages` or, for a custom message, from a constants class in the Application layer. Never repeat a string literal in several places.
- Don't catch an exception in a handler. Don't swallow one anywhere unless the design says the plug-in must not block the operation.
- Don't bake one use case into a generic plug-in's name or constants. When configuration can't express a new requirement, add a small class chosen by configuration rather than a flag or an `if`.
