---
name: dataverse-schema
description: Looks up Dataverse table and column metadata (type, length, required level, option values, date behaviour) from the unpacked solution, finds the generated property name and CLR type in the early-bound model, and regenerates that model with pac modelbuilder. Use before writing code, test data or fakers that name Dataverse columns, or when the model is missing a table or column.
---

# Dataverse schema

Intended for `developer` and `quality-engineer`, but usable by anyone. Load `power-platform-standards` first. Never open whole generated model files, which are large: look names up with the scripts.

Tables, columns and option sets are changed by the human in the development environment and synchronised into the solution. This skill only reads that result and regenerates the model from it.

## Scripts

Run them with PowerShell 7, for example `pwsh -NoProfile -File <this skill's folder>/scripts/Get-EntityFieldMetadata.ps1`. Each has `-?` help with every parameter and an example.

| Script | Answers |
| --- | --- |
| [Get-EntityFieldMetadata.ps1](scripts/Get-EntityFieldMetadata.ps1) | What a column allows: type, required level, length, range, format, date behaviour, option values, whether it can be set on create. Reads `Entity.xml` and the option sets from the unpacked solution |
| [Get-EntityPropertyClrType.ps1](scripts/Get-EntityPropertyClrType.ps1) | What the generated property is called and its exact CLR type. Reads the generated entity class |

Use both for any column you name in code. Don't infer the property name from the logical name, because the model builder's casing varies per column. Don't infer the CLR type from the metadata type, because nullable wrapping, option set enum names and collection types depend on the generated code.

## Looking up a column

1. **Discover the paths.** The unpacked solution is the folder that holds `Solution.xml` and `Entities/` (see [project-facts.md](../power-platform-standards/references/project-facts.md)). The model is in the Dataverse shared project (see `dataverse-plugins`, [project-structure.md](../dataverse-plugins/references/project-structure.md)): find the generated entity classes, which carry `AttributeLogicalName` annotations. Confirm both paths with the user.
2. **Get the constraints**, so fakers and validation match the platform: `Get-EntityFieldMetadata.ps1 -SolutionPath <solution folder> -EntityLogicalName abc_inspection -Field abc_scheduledon`. A date-only column mustn't be given a time of day. Use only values from the option set.
3. **Get the property and type**: `Get-EntityPropertyClrType.ps1 -ModelPath <model folder> -EntityLogicalName abc_inspection -AttributeName abc_scheduledon`.
4. **If a column or table isn't found**, the model may be out of date. Say so, and regenerate it (below) rather than working around it with late-bound names. Names that arrive through configuration or inputs are late-bound by design.

## Regenerating the early-bound model

Do this when code needs a table or column that the synchronised solution has and the model lacks. If the solution doesn't have it either, the human must create it in their development environment first.

1. **Confirm two facts with the user, every time. Don't store them:**
   - the environment URL (`https://<org>.crm<n>.dynamics.com`), which should be the work item's development environment;
   - the path of the model builder settings file (`builderSettings.json` or similar). Find candidates in the repository, and offer them.
2. **Check they're signed in** to that environment with `pac auth list`. If not, ask them to run `pac auth create --environment <environment-url>`. Never ask for or handle credentials yourself.
3. **Run it in the folder that contains the model**:

   ```powershell
   pac modelbuilder build --environment <environment-url> -stf <builder-settings-path> --outdirectory ./
   ```

4. **Review the diff.** Expect additions for the new table or column and nothing else. Report unrelated changes, which usually mean the environment's schema differs from the solution's, and don't commit them without the user's approval.
5. **Build** with `dotnet-build-verification` to prove the regenerated model compiles, then continue with the task.

## Rules

- Generated model files are never hand-edited. Fix the settings or the environment, then regenerate.
- Regenerating changes many files. Do it only for a reason, say why, and keep it in its own commit with the code that needs it.
- Report what you looked up: the logical name, the property name, the CLR type and the constraints used.
