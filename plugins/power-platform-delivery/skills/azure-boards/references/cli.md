# Azure DevOps CLI and REST API

Commands for the CLI route. `<org>` is the configured organisation URL and `<project>` is the project name. Add `-o json`, write the output to a temporary file and parse the file rather than reading the console.

## Read

| Need | Command |
| --- | --- |
| One item, with its fields and links | `az boards work-item show --id <id> --org <org>` |
| A search | `az boards query --wiql "<query>" --org <org> --project <project>` |
| An item's comments | `az devops invoke --area wit --resource comments --route-parameters project=<project> workItemId=<id> --http-method GET --api-version 6.0-preview --org <org>` |

- `work-item show` doesn't accept `--project`, but `query` does.
- There's no `work-item list` command. Search with a WIQL query instead:

  ```sql
  SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = 'User Story' AND [System.Title] CONTAINS 'inspection'
  ```

- In an item's `relations`, `System.LinkTypes.Hierarchy-Reverse` points to its parent and `System.LinkTypes.Hierarchy-Forward` to a child.

## Write

| Change | Command |
| --- | --- |
| Create | `az boards work-item create --type "<type>" --title "<title>" --area "<area path>" --description "<html>" --fields "Microsoft.VSTS.Common.AcceptanceCriteria=<html>" --org <org> --project <project>` |
| Update | `az boards work-item update --id <id> --fields "<field>=<value>" --org <org>` |
| Link to a parent | `az boards work-item relation add --id <child id> --relation-type parent --target-id <parent id> --org <org>` |
| Comment | `az devops invoke --area wit --resource comments --route-parameters project=<project> workItemId=<id> --http-method POST --in-file <file> --api-version 6.0-preview --org <org>`, where the file holds `{"text": "<html>"}` |

Common fields are `System.Title`, `System.Description`, `System.State`, `System.AreaPath`, `System.IterationPath` and `Microsoft.VSTS.Common.AcceptanceCriteria`. Some process templates use other names. If an update seems to be ignored, check the field names on the item.

## Known quirks

- **Windows cuts arguments at the first newline.** `az.cmd` silently truncates an argument at its first line break. Build HTML on one line, and fetch the item again to check the field. For long content, use `--in-file` where the command supports it.
- **Ampersands break arguments.** Don't use a literal `&`, even escaped as `&amp;`. Write "and", or `->` for a sequence. Angle brackets are fine.
- **Comment API version.** Use `6.0-preview`. A version with a `-preview.N` suffix fails with "could not convert string to float".

## REST API

When the CLI isn't available, call the work item endpoints (`_apis/wit/workitems`, `_apis/wit/wiql` and `_apis/wit/workItems/<id>/comments`) with the token from the environment variable. Creating and updating take a JSON Patch document (`application/json-patch+json`). The rules in the skill apply in the same way.
