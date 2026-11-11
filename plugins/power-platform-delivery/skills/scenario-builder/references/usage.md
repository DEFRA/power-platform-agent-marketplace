# Using scenarios from tests

Conventions for calling builders from acceptance steps and integration tests. For the classes themselves see [templates.md](templates.md).

## Formatting

Use standard C# formatting. Put each chained call on its own line with the leading `.` at the start of the line, and indent one level more for each nested builder. Don't crowd several calls onto one line.

```csharp
var scenario = await this.scenarioBuilder
    .ApplicantSubmitsCase(a => a
        .WithIsUrgent(true))
    .InspectorProcessesCase(a => a
        .ByAssigningInspection(b => b
            .WithInspector(this.activeUserId))
        .AndAllPreviousSteps())
    .BuildAsync();
```

## Chains

**One event.** Configure only what the test cares about:

```csharp
var scenario = await this.scenarioBuilder
    .ApplicantSubmitsCase(a => a.WithIsUrgent(true))
    .BuildAsync();
```

**Drilling into a composite event.** A composite event's builder runs only the steps you configure. Add `AndAllPreviousSteps()` so the earlier, unconfigured steps still run. `AndAllOtherSteps()` runs every unconfigured step, earlier and later. Forgetting this silently skips setup that later assertions depend on.

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

**Resuming.** Several setup steps in one test, such as separate `Given` steps, must compose rather than create competing records. Check whether the test context already holds a scenario. If it does, build on it with `BuildAsync(scenario)`. Otherwise build a new one, then store the result.

```csharp
var builder = this.scenarioBuilder
    .InspectorProcessesCase(a => a
        .ByAssigningInspection(b => b.WithInspector(this.activeUserId))
        .AndAllPreviousSteps());

var scenario = this.context.TryGetValue<CaseScenario>(out var existing)
    ? await builder.BuildAsync(existing)
    : await builder.BuildAsync();

this.context.Set(scenario);
```

**Correlating two scenarios.** `WithRules` extends the underlying faker, so two otherwise independent scenarios can share a generated value, such as the same applicant:

```csharp
var secondScenario = await this.scenarioBuilder
    .ApplicantSubmitsCase(a => a
        .WithRules(r => r
            .RuleFor(c => c.abc_ApplicantId, firstScenario.ApplicantSubmitsCaseEvent.ApplicantId)))
    .BuildAsync();
```

## Reading results

- Store the built scenario in the test's context straight after `BuildAsync()`, and read it back from there.
- Read captured values from the scenario's event properties, such as `scenario.ApplicantSubmitsCaseEvent.CaseId`, rather than querying Dataverse again for something the builder already holds.

## Choosing the approach

| | Pattern |
| --- | --- |
| **Preferred** | Compose scenarios with `scenarioBuilder.<Event>(...).BuildAsync()`. Drill into composite events with `AndAllPreviousSteps()`. Store and resume the scenario through the test context. Configure fakers through builder `With*` methods. Register builders with a real logger |
| **Acceptable** | Direct `ServiceClient` calls, through the client factory, for one-off reference or lookup data that no event covers. If the same setup recurs, add a builder event |
| **Discouraged** | Building a journey by hand with direct client calls when an event already exists. It duplicates setup, bypasses the captured outputs other steps rely on, and hides why a record is in its state. Registering builders with a null logger |

Reference data that never changes, such as lists of categories or types, belongs in the package's seed data, not in a scenario. See `package-deployer`.
