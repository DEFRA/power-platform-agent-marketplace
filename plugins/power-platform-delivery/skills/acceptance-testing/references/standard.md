# Acceptance testing standard

The conventions for Reqnroll step definitions that drive a model-driven app with Power Playwright and set up data with ScenarioBuilder. Feature file naming, layout, tags and wording are in `bdd-scenarios`, so they aren't repeated here.

## Step classes

- **One class per entity or domain**, not per `Given`, `When` or `Then`. Every step about inspections, whether it sets up, acts or verifies, lives in `InspectionSteps`. Steps may be grouped by technique (for example under a `Playwright` folder) if the project does.
- **Wording.**
  - `Given` establishes state: "an applicant has submitted a case", "I am logged in as…", "the inspection is assigned to me". It sets data up through ScenarioBuilder or direct Dataverse setup, never the UI.
  - `When` is a single user action: "I click the 'Cancel' command", "I enter the following details", "I save the record".
  - `Then` is an observable outcome: "I see the following fields", "the record is saved".
  - `But` contrasts with a previous assertion. It isn't a second, independent one.
- **Prefer table-driven steps** ("I see the following fields", "I enter the following details") to one step per field. To check another field, add a row to the table, not a new step. Write a single-field step only when the field needs handling that no table step can express.
- **Look up by display name.** Resolve fields, subgrids and tables from the display name used in the feature file to the right control or logical name through a metadata service, so steps stay declarative and tests don't hard-code logical names or IDs.
- **Transformations.** Use `[StepArgumentTransformation]` to turn recurring Gherkin phrases or tables into domain types (a "can|cannot" into a `bool`, a table into a list of enum values). Add one when the same conversion is needed twice, instead of parsing text in a step.

## Sharing state

Two mechanisms, each for its own purpose:

- **A Power Playwright context object** (constructor-injected): where the browser is now. It holds the active page and the active user's ID, and validates that there is a session or that the page is the right type. Every UI step reads and writes `ActivePage` rather than keeping its own page reference, which lets step classes work together.
- **Reqnroll's `ScenarioContext`**: domain data that later steps need, such as scenarios, IDs and captured values. Use constants for the keys, held in one file, so a key is never typed out twice.

Register shared services in the container hooks, in one place (see [runtime.md](runtime.md)), and not across step classes.

## Isolation and data

- Each scenario builds only what it needs, from newly created records. It never relies on another scenario's leftover state.
- It runs as a user from the pool (see [users-and-personas.md](../../test-foundations/references/users-and-personas.md)), so scenarios run in parallel without colliding on one user.
- Read-only reference data, such as categories, types or locations, is part of the package's seed data and is deployed once. It isn't created per run or per scenario. See `package-deployer`.
- If a scenario creates data that persists beyond the run and could affect others, add a clean-up hook triggered by a tag, and name the tag after the hook's intent. Add a new tag only with its hook.

## Choosing the approach

|                 | Pattern                                                                                                                                                                                                                                                                                                                                                               |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Preferred**   | ScenarioBuilder for all data setup. Power Playwright abstractions for all UI work. FluentAssertions, in an `AssertionScope` where related. Plain domain-language exceptions in `Given` and `When`. Entity-centred, table-driven steps. A real logger for builders, with each setup call logged. Registrations in the hooks. Transformations for recurring conversions |
| **Acceptable**  | Direct client calls, through the client factory, for one-off reference or lookup data with no event yet. A bounded retry around an eventually consistent condition                                                                                                                                                                                                    |
| **Discouraged** | Raw Playwright locators or script evaluation where Power Playwright has an abstraction. `Task.Delay` as a wait. Assertion-library exceptions in `Given` or `When`. A null logger. Registrations scattered across step classes                                                                                                                                         |

[anti-patterns.md](anti-patterns.md) gives the reasons and the alternatives.

## Adding a scenario's automation

1. Find the step class for the entity. Reuse its wording where the meaning genuinely matches.
2. Build every precondition with an existing ScenarioBuilder chain. Add an event only when none fits.
3. Use Power Playwright steps only for the action and checks under test.
4. Run the scenario on its own, and with its neighbours, to confirm that it has no ordering dependency.
