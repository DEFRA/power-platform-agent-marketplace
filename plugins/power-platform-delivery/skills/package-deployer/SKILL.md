---
name: package-deployer
description: Changes a Package Deployer package project safely - its structure, solution import order, core versus seed data, the standard and standalone ImportConfig files and their parity, and the extension hooks - so every change deploys with no manual steps. Use when a change adds or removes a solution, data, a setting or an import step, or must reach every environment through the package.
---

# Package Deployer

Intended for `developer`, but usable by anyone. Load `power-platform-standards` first. The lifecycle that builds and deploys the package is in the `power-platform-design` skill (`references/alm.md`). You design for it and never run or edit pipelines.

A change to the package is a deployment change. It reaches every environment, so state its effect on the deployed package in the design proposal and ask for approval first.

## Discover the package

Find the package project (`*.csproj` that references Package Deployer, with a class deriving from `PackageTemplateBase` or `ImportExtension`) and confirm it with the user, as in [project-facts.md](../power-platform-standards/references/project-facts.md). Read it and its neighbours before changing anything. A project's own structure wins over the one below.

## Typical structure

The common template is `Capgemini.PowerApps.PackageDeployerTemplate`. Names vary with the project.

| Part                                                        | Purpose                                                                                                                                      |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| The extension class                                         | Deployment hooks: settings read with `GetSetting<T>`, solution import decisions, seed data import and other steps before or after the import |
| The project file                                            | The solution project references and their import order, dependency solutions, and the target that copies the data folder into the package    |
| `ImportConfig.xml`                                          | The standard configuration: the data imports and the processes to activate or deactivate after import                                        |
| `ImportConfig.Standalone.xml` (or the project's equivalent) | The configuration for ephemeral development and test environments, selected by the pipeline                                                  |
| The package manifest                                        | Package metadata                                                                                                                             |
| The data folder                                             | Configuration Migration datasets, split into core and seed data                                                                              |

## Rules

- **Zero manual steps.** Anything an environment needs must arrive through the package: solutions, reference and configuration data, settings and activation state. If a design needs someone to create a record or switch something on after deployment, change the design. Environments are rebuilt often, so a "one-off" step recurs and quietly regresses.
- **Core versus seed data.** Core data is configuration and reference data every environment needs, such as a global setting or a lookup table's rows. It is imported always. Seed data is optional sample data for development and testing, imported only when a setting asks for it. Put each record in the right set. Never let test data into core.
- **Choose the mechanism for new configuration** and say which in the design: (a) a core data record, (b) an environment variable, which has no audit trail of changes, or (c) a hook in the extension class, or an existing process, for logic data can't express.
- **Keep the two `ImportConfig` files consistent.** A difference must be deliberate and explained, such as an integrated process that is deactivated only in standalone environments. Check both whenever you change one.
- **Don't edit the `solutions` element of `ImportConfig.xml`.** It is populated at build time from the project's solution references.
- **Settings come from the pipeline.** Read them with `GetSetting<T>` and give each a sensible default. Never write environment URLs, credentials, tokens or connection strings into the package.
- **Environment differences are import configuration, not code.** Don't branch on an environment name in a hook.
- **The data folder's content is exported from a development environment** with the Configuration Migration tool. Change it only if the user asks, and say it needs re-exporting by the human.
- **Retire, don't delete.** Mark processes and steps inactive through the import configuration, deactivate or scope views and forms, and keep tables, columns and choices. Removing them breaks consumers that depend on them.
- **Hooks are code.** Follow `dataverse-plugins` standards (small classes, constructor injection, logging, tests) and `dotnet-build-verification`.

## Procedure

1. **Discover and read** the package project, both `ImportConfig` files and the extension class.
2. **State the effect** of the change on the deployed package: what appears, changes or is removed in each environment, in what order, and how the change gets there with no manual step.
3. **Propose and wait for approval.** Include the mechanism chosen for any new configuration and the parity check on the two import configurations.
4. **Make the change** and keep each `ImportConfig` edit minimal.
5. **Build it** with `dotnet build <package project>`. It builds the solutions, assemblies and web resources it references, so it needs the Power Platform build tools. If the machine can't build it, say so, and name pull request validation as the check that remains.
6. **Report** the effect on the package, how the change deploys, what the human must do in a development environment (for example re-export data), and the parity check.
