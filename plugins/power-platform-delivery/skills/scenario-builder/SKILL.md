---
name: scenario-builder
description: Builds and extends the shared test-data project that sets up Dataverse state for acceptance and integration tests, using ScenarioBuilder events, composite events and scenarios with Bogus fakers. Use when a test needs data that no scenario provides, when adding a fake or event, or when reviewing test setup.
---

# Scenario builder

Intended for `quality-engineer` and `developer`, but usable by anyone. Load `power-platform-standards` first, and `test-foundations` for the users, clients, conventions and logging that events rely on.

Test data is created the way production data is created: through the same API calls and business processes, never by writing fields that a real action would derive. [ScenarioBuilder](https://github.com/ewingjm/scenario-builder) is a builder-pattern framework for this. It makes tests:

- **Declarative.** A test configures only what matters to it. Everything else runs with sensible defaults.
- **Single-sourced.** The steps of a business process live in one `Scenario`, so a process change touches one place, not dozens of tests.
- **Resilient.** A test doesn't reference steps it doesn't care about, so unrelated process changes don't break it.

This also makes tests run unattended against a freshly deployed environment (see [alm.md](../power-platform-design/references/alm.md)): every test builds its own data and relies on none that was left behind.

| Reference | Load it when |
| --- | --- |
| [templates.md](references/templates.md) | Writing an event, composite event or scenario class |
| [usage.md](references/usage.md) | Calling builders from a test: chains, drilling in, resuming, correlating, reading outputs |
| [fakers.md](references/fakers.md) | Writing or changing a Bogus faker, and `assets/RecordFaker.cs` |

## Acting as a persona

An event acts as the persona that would perform the real action. It asks the client factory for that persona's client, and logs the request. It never assigns roles or builds its own client. Who owns and disposes each client, how the pool leases users and how the factory is created are in [clients.md](../test-foundations/references/clients.md) and [users-and-personas.md](../test-foundations/references/users-and-personas.md). The wait, retry and logging rules events follow are in [common-conventions.md](../test-foundations/references/common-conventions.md).

## Where the code lives

Discover the shared test-data project (see [project-facts.md](../power-platform-standards/references/project-facts.md)): the one that references ScenarioBuilder and Bogus, and that both the acceptance and integration test projects reference. Confirm it with the user. New events, scenarios and fakers go there, never in a test project or in ad hoc test code. If the project has none, propose one and wait for approval.

Match the ScenarioBuilder version the project references: its API changes between versions (for example whether `ConfigureEvent` takes an event ID).

## Core concepts

This table is the single statement of the structural rules. The procedure and checklist refer to it.

| Concept | Rule |
| --- | --- |
| `Event` | One actor action against the API. Implements `ExecuteAsync(ScenarioContext)` |
| `Event.Info` | Nested class declaring the event's outputs. `ExecuteAsync` sets one context value keyed by the **event's own class name**, `context.Set(nameof(ApplicantSubmitsCaseEvent), new Info { ... })`. Never a per-property key or a typed-out string |
| `Event.Builder` | Nested `Builder<TEvent>` with `With*` overrides. Field names and types **must match the event's fields exactly**, because the base builder copies values across by name. Value-type fields are **nullable** (`bool?`, `Guid?`) on both, so "not configured" differs from the default. Every overridable field has a safe default |
| `CompositeEvent` | A business process made of other events through `[ComposeUsing]`. Name it with a verb that suggests configurable steps ("Processes"), not a single step ("Completes") |
| `CompositeEvent.Builder` | One `By*` method per child, each only calling `ConfigureEvent`. Only configured children run unless `.AndAllPreviousSteps()` or `.AndAllOtherSteps()` is used |
| `Scenario` | The test-facing entry point, composed with `[ComposeUsing]`. For each event whose outputs a test may need, a property **named after the event class** and typed as its `Info`. It's filled from the context by matching names |
| `Scenario.Builder` | One configurator method per top-level step, each only calling `ConfigureEvent`. Overrides `InitializeServices` to register what events need injected: the client factory and a logger provider |
| `ScenarioContext` | The bag events pass values through. Earlier events `Set`, later events `Get` |
| `BuildAsync` | Runs the configured steps, plus any unconfigured steps that precede them at scenario level. `BuildAsync(scenario)` resumes an existing scenario |

## Procedure

1. **Name the process, not the test.** `CaseScenario` and `ApplicantSubmitsCaseEvent`, not the name of the test that uses them.
2. **Reuse first.** Search the shared project for an event, composite event or scenario that covers the step. Extend it with a `With*` or `By*` method or a new `[ComposeUsing]` step rather than duplicate logic in a new class or in the test.
3. **Look up the columns you set.** Use the `dataverse-schema` skill for constraints, property names and CLR types. Don't guess them from the logical name. See [fakers.md](references/fakers.md).
4. **Write the leaf events first**, following [templates.md](references/templates.md). Each makes the API call a real user or system would make, as the persona that would make it, and logs it.
5. **Group** a process into a `CompositeEvent` when callers may want to stop partway, such as "a case has been assigned" against "a case has been fully processed".
6. **Define or extend the `Scenario`** and its builder: `[ComposeUsing]` order, an `EventIds` class, output properties and one configurator per top-level step.
7. **Prove it.** Use it from a test and run that test. Say if you couldn't run it.

## Checklist

- [ ] Every public member has an XML doc comment if the project enforces them.
- [ ] Names describe the real business action.
- [ ] An existing event, composite event or scenario was extended where possible.
- [ ] Builder fields match the event's fields by name and type, value types are nullable, and every field has a default.
- [ ] Outputs are one `Info` object set under the event's class name, and scenario properties follow the naming rule.
- [ ] Builder methods only call `ConfigureEvent`: no inline logic.
- [ ] No shortcuts: the events make the same API calls a real user or system would.
- [ ] Each request is logged with the operation and its identifying values, through a real logger.
- [ ] Fakers inherit `RecordFaker<TEntity>` and produce valid records. Constraints, property names and types were looked up, not guessed.
- [ ] Each event acts as the persona that would do it, never as an administrator by default.
