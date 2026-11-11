---
name: customisation-xml
description: Hand-edits the solution customisation XML that Microsoft supports editing - ribbon, site map, forms and dashboards (FormXml) and views (saved queries) - and says what must instead be done in the development environment. Use when a change needs a new form, view, ribbon button, site map entry or dashboard, or when deciding whether a solution change can be made in a file at all.
---

# Customisation XML

Intended for `developer`, but usable by anyone. Load `power-platform-standards` first. Per-component rules and patterns are in [components.md](references/components.md).

Solution metadata is synchronised from the development environment, never hand-written, with one exception: the components Microsoft documents as safe to edit in the customisations file ([when to edit the customizations file](https://learn.microsoft.com/en-us/power-platform/alm/when-edit-customization-file)). Everything else is the human's work in the environment.

## What goes where

| Change                                                                        | Who and where             |
| ----------------------------------------------------------------------------- | ------------------------- |
| Ribbon (`RibbonDiffXml`)                                                      | Developer, in the file    |
| Site map                                                                      | Developer, in the file    |
| Forms and dashboards (FormXml)                                                | Developer, in the file    |
| Views (saved queries)                                                         | Developer, in the file    |
| Tables, columns, relationships, option sets                                   | Human, in the environment |
| Processes, flows, business rules                                              | Human, in the environment |
| Plug-in step and web resource registrations                                   | Human, in the environment |
| Security roles, environment variables, connection references, app definitions | Human, in the environment |

When a request needs both, say which parts are the human's and in what order they come: tables, columns, processes, flows, business rules, registrations, and only then the file edits that rely on them (a form can't show a column that doesn't exist yet). Prefer to do the human's parts first, and wait for the synchronised result before editing.

## Rules

- **Never customise managed components.** Create a new form or view for your app, with a new GUID, and don't change one that another solution owns. Editing a managed form or view makes it harder to upgrade and affects every app that uses it.
- **Make the smallest edit** that delivers the request, in the existing files. Don't reformat or reorder XML you aren't changing, because the diff must show only the change.
- **Use publisher-prefixed names and fresh GUIDs** for everything you add. Never reuse a GUID or copy a form's identifiers.
- **Reference only what exists.** A column in a form or view, a web resource in a ribbon or form library and a command's function name must exist in the synchronised solution or be created by the human first. If one is missing, stop and say so.
- **Keep it deployable.** The edited file must pack and deploy with no manual step.
- **Prefer the designers for anything they can express.** For example, new command bar buttons are usually simpler in the modern command designer, by the human. Use `RibbonDiffXml` when the designer can't do it, or the project already uses it, and say why.

## Procedure

1. **Discover the solution.** Find the unpacked solution folder that owns the component (the `Solution.xml` and `Customizations.xml`, or the per-component files an unpack produces), and its publisher prefix. Confirm it with the user, as in [project-facts.md](../power-platform-standards/references/project-facts.md). Don't assume a layout: unpacked solutions differ with the unpack options.
2. **Check ownership.** Is the component managed or owned by another solution? If so, plan a new component instead of an edit.
3. **Propose the edit and wait for approval** when it is more than trivial. State the component, the file, the new IDs, what it references and what the human must do first.
4. **Edit** using [components.md](references/components.md), as one change per component.
5. **Verify.** Check each of these, and report the evidence:
   - the XML is well formed (`[xml](Get-Content -Raw <file>)` in PowerShell 7 parses it);
   - every new ID is a unique GUID, and every reference resolves;
   - the solution still packs, for example `pac solution pack` to a temporary folder outside the repository;
   - the diff contains only the intended change.
6. **Report and hand off.** List the files changed and what the human must check in an environment: import the package, open the form, view or ribbon, and confirm it behaves as intended. State that the next solution sync must keep your edit. If a sync drops or rewrites it, tell the human.
7. **Commit** with `commit-and-pull-request`. The skill explains when a `+semver` line is needed. It isn't for a commit that changes the solution's own files.
