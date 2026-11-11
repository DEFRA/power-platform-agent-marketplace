# Worked example

An integration test in the neutral domain, using MSTest and FluentAssertions. `CaseScenarioBuilder`, `InspectionState` and `CloseAsync` stand for the project's own equivalents.

```csharp
[TestMethod]
public async Task Close_WhenCaseHasAnOpenInspection_CancelsInspection()
{
    var scenario = await this.CaseScenarioBuilder
        .ApplicantSubmitsCase()
        .InspectorProcessesCase(a => a
            .ByAssigningInspection()
            .AndAllPreviousSteps())
        .BuildAsync();

    abc_Inspection actualInspection;

    using (var client = this.ClientFactory.GetClient(scenario.InspectorAssignsInspectionEvent.InspectorId))
    {
        await client.CloseAsync(scenario.ApplicantSubmitsCaseEvent.CaseId);

        actualInspection = await client.RetrieveInspectionAsync(scenario.InspectorAssignsInspectionEvent.InspectionId);
    }

    actualInspection.StateCode.Should().Be(InspectionState.Cancelled, because: "closing a case should cancel its open inspections");
}
```

## What it shows

- **Name.** `Close_WhenCaseHasAnOpenInspection_CancelsInspection` states the action, the condition and the expectation.
- **Arrange.** The case and its assigned inspection come from a ScenarioBuilder chain, not direct record creation. The scenario exposes the IDs it created, so the test doesn't query Dataverse for data it already holds.
- **Act.** The client is for the inspector who owns the inspection, found by ID because the behaviour depends on the actual owner and not merely on a matching persona. It calls `CloseAsync`, the operation a real caller would use. If the behaviour belonged to a persona, the test would use the persona client instead.
- **Assert.** The state is retrieved through the same client and checked with one FluentAssertions assertion and a `because` reason. If the cancellation were made by an asynchronous step, the retrieval and assertion would sit inside a bounded retry.
- **Scope.** The client is in a `using` block, so its connection lasts for the Act and Assert, not the whole test.
- **Independence.** The test builds its own case and inspection, and relies on no other test.
