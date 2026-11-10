# Project facts: discover, confirm, configure

The plugin decides how work is done. The project supplies where things are and what they're called. Work out as much as you can from the repository, confirm it with the user, and ask only for what the repository can't tell you.

## Procedure

1. **Load config.** Read `.agent-config/power-platform.json` at the repository root if it exists. Validate it against [power-platform.schema.json](../assets/power-platform.schema.json) before using it (for example `Test-Json -Path <config> -SchemaFile <schema>` in PowerShell 7). If it is invalid, say which field is wrong and why. Don't continue with invalid config.
2. **Discover.** Gather only the facts the current task needs, using the table below. Re-discover each session. Never cache discovered facts in config.
3. **Confirm.** Show the user what you found in one short list and ask them to correct anything wrong. Where there are several candidates (for example more than one solution), ask which applies.
4. **Ask for the rest.** Ask only for facts that are config-only and missing. One question at a time, with a suggested answer where you can offer one.
5. **Store.** Write only config-only facts to `.agent-config/power-platform.json`, using [power-platform.example.json](../assets/power-platform.example.json) as a template. Show the user the change before saving. Never treat the example's values as defaults for a real project.
6. **Stop rather than guess.** If a needed fact is neither discoverable nor supplied, say what is missing and stop that part of the task.

## Facts and where they come from

| Fact | Source | How |
| --- | --- | --- |
| Solutions, unique names, publisher prefix | Discover | Find `*.cdsproj`. Read `UniqueName` and the publisher's `CustomizationPrefix` from each solution's `Solution.xml` |
| Plug-in, workflow, test and package projects | Discover, then confirm | Find `*.csproj` and `*.sln`. Classify by what each references (the Dataverse SDK for plug-ins and workflow activities, a test SDK for test projects, Package Deployer for packages) |
| Shared projects and the shared-code assembly | Discover, then confirm | Find `*.shproj` and the `*.projitems` each project imports. The shared-code assembly imports them all and is referenced in the `UnitTest` configuration |
| Web resource root and JavaScript namespace | Discover, then confirm | Find `package.json` and the existing web resource source |
| Base branch | Discover | `git symbolic-ref --short refs/remotes/origin/HEAD` |
| Repository host (whether `AB#` links apply) | Discover | `git remote get-url origin`: GitHub means `AB#` applies; Azure Repos means it doesn't |
| Model-driven app names | Discover | `AppModule.xml` files |
| Persona file for acceptance and integration tests | Discover | The `Persona` enum in the test projects' source |
| Azure Boards organisation, project, area path, work item types | **Config** | Ask the user |
| `pac modelbuilder` environment URL and settings path | **Ask each time** | Don't store them (see the `dataverse-schema` skill) |

## Config reference

`.agent-config/power-platform.json` holds only the config-only rows above. [power-platform.schema.json](../assets/power-platform.schema.json) is the authority; unknown properties are invalid, not ignored.

| Property | Required | Meaning |
| --- | --- | --- |
| `schemaVersion` | Yes | Schema version the file was written against (`1.0`) |
| `azureBoards` | No | Omit if the project doesn't use Azure Boards |
| `azureBoards.organization` | Yes, if `azureBoards` is present | Organisation URL or name |
| `azureBoards.project` | Yes, if present | Project name |
| `azureBoards.workItemTypes` | Yes, if present | Names of the `epic`, `feature`, `story` and `task` types in the project's process template |
| `azureBoards.areaPath` | No | Default area path for new work items |

If the file's `schemaVersion` is older than the schema, tell the user which new required fields are missing and offer to fill them in. Don't default silently.
