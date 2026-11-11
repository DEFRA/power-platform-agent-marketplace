# Configuration data and non-breaking change

## Configuration and reference data

A design that adds a configuration or reference record isn't complete until the record's path into every environment is defined. Environments are rebuilt routinely, so a manual step is never one-off: it recurs on every rebuild and silently regresses.

Choose one path, prefer the one the project already uses, and state it in the ALM considerations:

| Path | Use it for | Watch out for |
| --- | --- | --- |
| A core Configuration Migration data set that the package always imports | Records every environment needs, whatever the environment | Keep it separate from optional seed or test data, which isn't imported everywhere |
| An environment variable | A single value that can differ by environment | It keeps no history of changes, which some rule tables need |
| A setup routine in an existing flow, workflow or the package's import hooks | Records created conditionally or derived from other data | It runs on every deployment, so it must cope with records that already exist |

How the package imports data and runs its import hooks is covered by `package-deployer`. If none of these paths works, the design has a blocking gap. Never accept manual creation as the answer.

## Changing a component others depend on

Build to contract. Deleting a component isn't routine, because every downstream environment then needs an upgrade step to remove it.

1. **Change additively.** Add rather than rename or remove. Put new behaviour behind a feature flag, such as an environment variable or a configuration record, rather than switching over in one step.
2. **Resolve every dependent.** Find each flow, plug-in, view, form, integration, table and column that uses the component, and remove or migrate it first. Marking a component obsolete doesn't resolve its dependents.
3. **Mark it obsolete rather than delete it.**
   - Processes and plug-in steps: deactivate them through the package's import configuration (see `package-deployer`).
   - Views and forms: deactivate them, or restrict them to administrators.
   - Tables, columns and choices: keep them in the schema, hidden or read-only where needed.
4. **Log it.** Add a row to the project's deprecation log when you mark a component obsolete, and remove the row once the component is deleted. If the project has no log, start one from the [template](../assets/deprecated-components.md).
5. **Remove in a batch.** Delete obsolete components in a separate, scheduled clean-up work item once they're confirmed unused.
