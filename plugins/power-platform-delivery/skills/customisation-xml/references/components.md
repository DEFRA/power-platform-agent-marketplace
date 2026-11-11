# Component notes

How to edit each supported component. File locations vary with how the solution is unpacked, so find the existing component first and follow its neighbours. Examples use the neutral domain (the Inspection table, prefix `abc_`).

## Forms and dashboards (FormXml)

- A form is one file per form, holding a `<form>` element with `<tabs>`, `<sections>`, `<cell>` and `<control>` elements, plus `<formLibraries>` and `<events>`.
- **New form:** copy a sibling form as the starting point, give it a new `formid` GUID and a new name, and set its localised names and description. Don't reuse the original's IDs. Add the form's entry wherever the solution lists forms (the unpacked entity's form listing and, for a model-driven app, its app definition, which is the human's change if the app designer owns it).
- **Adding a column:** add a `<cell>` containing a `<control>` whose `datafieldname` is the column's logical name and whose `classid` matches the column's type. Copy the `classid` from an existing control of the same type on a sibling form. Give the control and cell fresh GUIDs and unique `id`s.
- **Wiring a script:** add the web resource to `<formLibraries>` as `<Library name="<web resource name>" libraryUniqueId="{GUID}" />`, and a `<Handler>` under the event with `functionName`, `libraryName`, a new `handlerUniqueId`, `enabled="true"`, `parameters` (the configuration) and `passExecutionContext="true"` when the handler takes `executionContext`. The web resource must already be in the solution (the human registers it). See `web-resources`.
- **Dashboards** follow the same rules: new GUIDs, only unmanaged ones owned by this solution, and controls that reference views and charts that exist.
- A form never shows a column that isn't in the model. Ask the human to add the column first.

## Views (saved queries)

- A view has a `<savedquery>` with a `<fetch>` (FetchXML) and a `<layoutxml>` (the grid), and a `querytype` (public views are `0`).
- **New view:** copy a sibling, then give it a new `savedqueryid` GUID, a name and a description. Set `isdefault` to `0` unless the user wants it to be the default.
- FetchXML: use logical names, select only needed columns with `<attribute>`, and put filters in `<filter>`. The `layoutxml` `<cell>` names must be in the fetch. Set `<row name="result" id="<primary id column>">`.
- Every column and linked table must exist in the model. Prefer filters on indexed, non-calculated columns.
- Don't change a managed view. Create a new one for the app.

## Ribbon (RibbonDiffXml)

- `RibbonDiffXml` holds `<CustomActions>` (add controls), `<Templates>`, `<CommandDefinitions>` (what a control does), `<RuleDefinitions>` (when it shows or is enabled) and `<LocLabels>` (text).
- **Add a button:** a `<CustomAction>` placing a `<Button>` in a location, a `<CommandDefinition>` whose `<JavaScriptFunction FunctionName="<Namespace>.<handler>" Library="$webresource:<web resource name>">` runs the handler, and `<LocLabels>` for the label. Use the publisher prefix in every `Id` (`abc.Inspection.Form.Complete.Button`) and keep them unique.
- **Rules:** show or enable a button through `<DisplayRule>` and `<EnableRule>`, for example a form state, a selection count or a custom rule that calls a function. Reuse existing rules.
- **Hide a built-in control** with `<HideCustomAction>`. Don't remove it from the base definition.
- Pass `PrimaryControl` (and any other crm parameters) to the handler as the script expects. See the handler's registration notes from `web-resources`.
- Prefer the modern command designer for new buttons where it can do the job, which is the human's work.

## Site map

- A site map is a `<SiteMap>` with `<Area>`, `<Group>` and `<SubArea>` elements. A `<SubArea>` opens a table (`Entity="abc_inspection"`), a dashboard (`Url`), a web resource or a custom URL.
- Give every area, group and sub area a unique, prefixed `Id`. Keep titles and descriptions localised the same way as the existing entries.
- Add only entries the app needs, in the order the user wants. A sub area that opens a table needs that table in the app.
- If the project manages the app's navigation in the app designer, leave that to the human.

## Checks

- Well formed XML, with the same encoding, declaration and line endings as the file had.
- Unique GUIDs, in the same case and format as their neighbours.
- Every referenced column, table, view, web resource and function exists.
- The diff shows only the new or changed elements.
- The solution packs. Importing it and trying the component is the human's check.
