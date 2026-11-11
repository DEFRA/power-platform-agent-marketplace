# Power Playwright

How acceptance tests use the [Power Playwright](https://github.com/ewingjm/power-playwright) package to drive a model-driven app. Its own documentation covers the raw API (`IModelDrivenAppPage`, `IEntityRecordPage`, `IEntityListPage` and the control types). This describes how to use it consistently.

## Session

Create Power Playwright once per scenario and track the active page and user in a context object that steps share:

```csharp
public class PowerPlaywrightContext
{
    public IModelDrivenAppPage ActivePage { get; set; }
    public Guid ActiveUserId { get; set; }

    public void Validate() { /* throw if there's no active session */ }
    public void ValidatePage<TPageType>() { /* throw if ActivePage is the wrong type */ }
}
```

Every UI step reads and writes `ActivePage`, which is what lets steps in different classes follow one another ("open the record" in one, "check a field" in another).

## Navigation

```csharp
// The first navigation of a scenario launches the app and logs in.
homePage = await this.powerPlaywright.LaunchAppAsync(
    browserContext, this.testConfig.Url, appLogicalName, username, password);

// Open a new record form.
this.powerPlaywrightCtx.ActivePage = await this.powerPlaywrightCtx.ActivePage.ClientApi
    .OpenFormAsync("abc_inspection");

// Go straight to an existing record.
this.powerPlaywrightCtx.ActivePage = await this.powerPlaywrightCtx.ActivePage.ClientApi
    .NavigateToRecordAsync("abc_case", caseId);
```

Take the app logical name from `AppModule.xml`, and never hard-code it where the project already configures it. Navigating by record ID is quicker and steadier than searching, and a `Given` that opens a record is fine.

## Forms

Use the typed controls (`ITextControl`, `IDate`, `IDateTime`, `IChoice`, `ILookup`, `IYesNo`, `IReadOnlyGrid`, `IGridControl`) through `Form.GetField<T>()` and `Form.GetControl<T>()`. Don't use raw locators for form fields.

```csharp
// Set a value, keyed off the field's declared control type.
await this.ExecuteGenericFieldActionAsync(displayName, async (field, fieldContext) =>
{
    await field.SetValueAsync(fieldContext.ControlType, value);
    await this.RecordPage.Page.Keyboard.PressAsync("Tab"); // commits the field: no abstraction exists
});

// Set a date when the control type is known.
var control = this.RecordPage.Form.GetField<IDate>("abc_scheduledon").Control;
await control.SetValueAsync(DateTime.Today.AddDays(3));

// Read a value back to assert on.
var actualValue = await field.GetValueAsync(fieldContext.ControlType);
```

Write `ExecuteGenericFieldActionAsync` and `ExecuteGenericDataSetActionAsync` helpers once, in the record page step class. They resolve a field or subgrid from its **display name** to the right control, so features stay declarative:

```gherkin
Then I see the following fields
    | Field          | Populated | Editable | Requirement Level |
    | Inspection date | false     | true     | Required          |
```

## Grids and subgrids

```csharp
// Open a record from a subgrid row.
await this.ExecuteGenericDataSetActionAsync(subgridDisplayName, async (dataSet, controlType) =>
{
    var control = dataSet.GetControl(controlType);
    this.powerPlaywrightCtx.ActivePage = await control.OpenRecordAsync(rowIndex);
});

// Select a row by a column's value.
var data = await dataSet.Control.GetRowDataAsync();
var rowToSelect = data.ToList().FindIndex(r => r[column] == value);
await dataSet.Control.ToggleSelectRowAsync(rowToSelect);

// Switch a list page's view, then read its columns.
await this.EntityListPage.DataSet.SwitchViewAsync(viewName);
var columns = await this.EntityListPage.DataSet.GetControl<IReadOnlyGrid>().GetColumnNamesAsync();
```

## Command bar and dialogs

```csharp
await this.RecordPage.Form.CommandBar.ClickCommandAsync("Save");

// A command that goes to another page.
this.powerPlaywrightCtx.ActivePage = await this.EntityListPage.DataSet.CommandBar
    .ClickCommandAsync<IEntityRecordPage>("New");

// A command that opens a dialog.
var quickCreate = await subgrid.CommandBar.ClickCommandWithDialogAsync<IQuickCreateForm>("New");
```

After a command that shows a confirmation or alert, confirm or dismiss it explicitly. The one exception is a scenario that ends on the dialog being shown. When a command's outcome dialog isn't guaranteed, check each possible type explicitly instead of assuming one, so an unexpected validation dialog gives a clear failure.

## Waiting

- **Preferred:** Power Playwright's own idle detection.

  ```csharp
  await page.ReloadAsync();
  await page.WaitForLoadStateAsync();
  await page.WaitForAppIdleAsync();
  ```

- **Acceptable:** a bounded retry around an assertion or query that depends on an eventually consistent backend (a plug-in on an asynchronous step, a flow, an integration). See [common-conventions.md](../../test-foundations/references/common-conventions.md).
- **Discouraged:** a bare `Task.Delay` or `Thread.Sleep`.

## Authentication

Users, and their credentials, come from the user pool (see [users-and-personas.md](../../test-foundations/references/users-and-personas.md)), never from values in a step. Caching of the signed-in browser state is in [runtime.md](runtime.md).

## Choosing the approach

|                 | Pattern                                                                                                                                                                                                                                            |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Preferred**   | Typed controls and pages (`GetField<T>`, `GetControl<T>`, `CommandBar.ClickCommandAsync`, the grid's `Control` methods). `WaitForAppIdleAsync()`. FluentAssertions                                                                                 |
| **Acceptable**  | A narrow, commented drop to raw Playwright where Power Playwright has no equivalent: pressing `Tab` to commit a field, `Escape` to close a flyout, or evaluating `Xrm.Utility` for global context. A bounded retry for eventually consistent state |
| **Discouraged** | Raw locators (`Page.GetByText(...)`, `ILocator.WaitForAsync`) where an abstraction exists. `Task.Delay` as a wait                                                                                                                                  |
