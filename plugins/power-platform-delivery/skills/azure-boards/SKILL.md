---
name: azure-boards
description: Reads, creates, updates, links and comments on Azure Boards work items through an Azure DevOps MCP server, the az CLI or the REST API, using the organisation, project and work item types from the shared project config. Covers querying first, confirming changes, safe retries for changes that aren't idempotent, and comment formatting. Use for any work item lookup or change.
---

# Azure Boards

Intended for `product-analyst` and `solution-architect`, but usable by anyone. Load `power-platform-standards` first. Azure Boards is the only work tracker this plugin supports. What goes into a work item is covered by `requirements-and-backlog`. This skill covers reading and writing it safely.

| Reference | Load it when |
| --- | --- |
| [cli.md](references/cli.md) | Using the az CLI or the REST API: commands, field names and known quirks |
| [comments.md](references/comments.md) | Writing a comment or a rich-text field, such as a description or acceptance criteria |

## Configuration

The organisation, project, default area path and work item type names come from the `azureBoards` section of `.agent-config/power-platform.json`. Load, validate and complete it with the [project-facts procedure](../power-platform-standards/references/project-facts.md), using the shared [schema](../power-platform-standards/assets/power-platform.schema.json) and [example](../power-platform-standards/assets/power-platform.example.json). Ask for an iteration path when you need one; it isn't stored. If the project doesn't use Azure Boards, say so and stop.

Always use the configured type names (for example `workItemTypes.story`). Process templates name them differently.

## Choosing a mechanism

Use the first that works, and say which you used:

1. **An Azure DevOps MCP server**, if one is connected and has work item tools.
2. **The Azure DevOps CLI** (`az boards` and `az devops invoke`). Check that the `azure-devops` extension is installed and that you're signed in (`az account show`).
3. **The REST API**, with a personal access token that the user has put in an environment variable. Never ask for a token in chat or write one to a file.

If none works, say why and give the user the content to enter by hand.

## Rules

- **Query first.** Fetch items fresh every time. Never trust an ID from memory or an earlier session. Search for duplicates before creating anything.
- **Confirm before changing.** Create or change items only when the user asks or confirms. Summarise a batch of planned changes before making it. Confirm the ID before a significant or destructive change, such as changing state, removing a link or overwriting a field.
- **Never lose information.** Merge new content with what a field already holds, unless the user asked for it to be replaced.
- **Changes aren't idempotent.** Creating, updating, linking and commenting can succeed even when the output looks like a failure. If the outcome is unclear, treat it as unknown and query again before retrying. Never retry blindly: that creates duplicates.
- **Verify after writing.** Fetch the item again and check every field you changed.
- **Tasks only on request**, each linked to its parent story.

## Before each operation

| Operation | You need |
| --- | --- |
| Create | The type, title, description, acceptance criteria (for a story), parent and area path |
| Update | The confirmed ID and the exact fields to change |
| Link | Both IDs and the relationship: parent, child, related, predecessor or successor |
| Comment | The target ID and content someone can act on |

If anything is missing, ask for it. Don't create an item with placeholder content.

## Procedure

1. Load the configuration and choose a mechanism.
2. Query the items involved and their links. Save JSON output to a temporary file and parse it.
3. Prepare the change, using the configured type names and formatting rich text as [comments.md](references/comments.md) describes.
4. Confirm the change with the user.
5. Make one change at a time, and check each result before making the next.
6. Fetch the items again and verify them.
7. Report the operation, work item type, IDs, relationships, a summary of any comment, and any warnings or failures.
