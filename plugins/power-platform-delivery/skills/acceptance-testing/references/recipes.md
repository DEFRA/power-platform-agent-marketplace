# Recipes

Worked solutions to common needs, in the neutral domain. Use these before inventing an approach. The builder chains are explained in `scenario-builder`'s [usage.md](../../scenario-builder/references/usage.md).

## A complete scenario

```gherkin
Feature: Reject a case

@issue:1234
Scenario Outline: An inspector rejects a case
    Given I am logged in to the 'Case Management' app as 'an inspector'
    And an applicant has submitted a '<Case type>' case
    And the case's inspection is assigned to me
    And I have opened the inspection
    When I click the 'Reject' command
    And I confirm the dialog
    And I enter one of the following options in the 'Reason for rejection' field
        | Option          |
        | Incomplete form |
        | Duplicate case  |
    And I save the record
    Then I see the following field values
        | Field         | Value    |
        | Status        | Inactive |
        | Status reason | Rejected |

    Examples:
        | Case type |
        | standard  |
        | urgent    |
```

It carries a traceability tag. Its `Given` steps delegate to ScenarioBuilder. It has one `When` action and one table-driven `Then`.

## Create a record for a journey

Compose a builder chain and store the result. If a scenario of the same type is already in the context, continue it with `BuildAsync(scenario)` instead of creating an unrelated second record.

```csharp
[Given("an applicant has submitted a {string} case")]
public async Task GivenAnApplicantHasSubmittedACase(string caseType)
{
    var scenario = await this.scenarioBuilder
        .ApplicantSubmitsCase(a => a.WithType(CaseType.Parse(caseType)))
        .BuildAsync();

    this.scenarioContext.Set(scenario);
}
```

## Progress a record to a point in its lifecycle

Drill into the composite event that owns the step. Don't create children directly and relate them by hand. Remember `AndAllPreviousSteps()` at every level, or the earlier setup is skipped silently.

```csharp
var scenario = await this.scenarioBuilder
    .ApplicantSubmitsCase()
    .InspectorProcessesCase(a => a
        .ByRecordingOutcome(b => b
            .WithOutcome(InspectionOutcome.Passed)
            .AndAllPreviousSteps())
        .AndAllPreviousSteps())
    .BuildAsync();
```

## Run as a persona

A scenario starts with one login step naming a persona (`bdd-scenarios` explains the choice). The step asks the user pool for a user and signs in as them. It never assigns roles. To change what a persona can do, change its configuration. See [users-and-personas.md](../../test-foundations/references/users-and-personas.md).

```gherkin
Given I am logged in to the 'Case Management' app as 'an inspector'
```

## Execute a command

```csharp
await this.RecordPage.Form.CommandBar.ClickCommandAsync("Cancel");
await this.RecordPage.ConfirmDialog.ConfirmAsync();
```

For a command that navigates or opens a dialog, keep the typed result (see [power-playwright.md](power-playwright.md)). Always confirm or dismiss a dialog explicitly.

## Check field values

One table-driven step resolves each field by display name:

```csharp
[Then("I see the following field values")]
public async Task ThenISeeTheFollowingFieldValues(Table table)
{
    using (new AssertionScope("field values"))
    {
        foreach (var row in table.Rows)
        {
            await this.ExecuteGenericFieldActionAsync(row["Field"], async (field, fieldContext) =>
            {
                var actual = await field.GetValueAsync(fieldContext.ControlType);

                actual.Should().Be(row["Value"], because: $"the '{row["Field"]}' field should have the expected value");
            });
        }
    }
}
```

## Check an automated outcome

When a plug-in, workflow or flow produces the result, poll with a bounded retry. Never assert at once. In a `Given` or `When`, throw a plain domain-language exception that names the record involved, not an assertion:

```csharp
await RetryExtensions.RetryUntilSucceedsAsync(
    async () =>
    {
        var inspection = await this.serviceClient.RetrieveInspectionForCaseAsync(caseId);

        if (inspection is null)
        {
            throw new InvalidOperationException($"The inspection for case '{caseId}' wasn't created within the expected time");
        }
    },
    this.logger);
```

## Check an integration's effect

The external system isn't called in tests. A ScenarioBuilder event for the external system's persona simulates its action against Dataverse, and you compose it like any other:

```csharp
var scenario = await this.scenarioBuilder
    .ApplicantSubmitsCase()
    .PaymentServiceConfirmsPayment()
    .BuildAsync();
```

This tests the effect of the integration, not its transport or the connection to the external system.

## Register a shared service

Register it in the container hooks, with an order that suits the services it needs (see [runtime.md](runtime.md)):

```csharp
[BeforeScenario(Order = -9998)]
public async Task SetupPowerPlaywright()
{
    var powerPlaywright = await PowerPlaywright.CreateAsync(new PowerPlaywrightConfiguration { /* ... */ });
    this.objectContainer.RegisterInstanceAs(powerPlaywright);
}
```

## A step that drives the UI

```csharp
[When("I cancel the case with a reason of {string}")]
public async Task WhenICancelTheCaseWithAReasonOf(string reason)
{
    var reasonField = this.RecordPage.Form.GetField<IChoice>("abc_reasonforcancelling");
    await reasonField.Control.SetValueAsync(reason);
    await this.RecordPage.Form.CommandBar.ClickCommandAsync("Cancel");
    await this.RecordPage.ConfirmDialog.ConfirmAsync();
}
```
