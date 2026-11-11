# Scenario style

## Structure

- **Setup in `Given`.** Put every precondition in a `Given`, even when a step that drives the screen could reach the same state. Prefer a data-level setup step. If none exists, report the binding that's needed.
- **Condense setup.** Drop a `Given` that the next step implies and that adds nothing. Write "Given an inspection is assigned to me", not "Given an applicant has requested an inspection" followed by "And the inspection is assigned to me". Keep a step that adds meaning, such as "an urgent inspection".
- **Articles.** Use "a" or "an" when an entity first appears, and "the" afterwards.
- **One action.** Each scenario has one contiguous `When`, with `And` for parts of the same action. A second action belongs in its own scenario. Never chain `When`, `Then`, `When`, `Then`.
- **Observable outcomes.** Each `Then` states a result someone can verify. Several `Then` and `And` steps for the one action are fine, but don't assert the same fact twice.
- **Abstract the procedure.** Collapse steps that don't matter to the behaviour into one higher-level step, such as "Given I have recorded an inspection", unless an intermediate step is the point of the scenario.
- **Business terms.** Don't name tabs, fields, controls or API calls unless the requirement mandates them. Write "And I have recorded an inspection", not "And I have selected the Inspections tab".

## Names

- Use the pattern subject, verb, object and context, such as "An inspector records a passed inspection".
- Keep names short. Leave out field-level detail unless it's the business meaning.
- For a negative scenario, write "attempts to", such as "An inspector attempts to record an inspection without a date". Use "cannot" only when the requirement is about a visible permission check.
- Name the behaviour, not the route through the screens.
- Batch related validation into one scenario when the rule is the same, such as one scenario for all the mandatory fields.

## Tables

- Pass a list of values as a data table, never as a list in the step text. A step with a fixed list in its wording can't be reused for a different list.
- For things laid out horizontally, such as the tabs on a form or the columns in a view, use a single header-only row: `| Details | Inspections | Notes |`.
- Before writing a new step that takes a table, search the step index for one that handles the same kind of list.

## Outlines

Use a `Scenario Outline` with `Examples` when the same behaviour must hold for a few named values that each matter. When any valid value would do, use a step that picks one rather than an outline that multiplies the run time.

## Tags

- Tag each scenario with the work items it verifies, as `@issue:<id>`. A scenario can carry several.
- `@ignore` is debt. Use it only alongside an `@issue:<id>` tag for the work item that will fix it.
- Follow the project's own tagging convention if it differs.

## Example

```gherkin
Feature: Record an inspection outcome

@issue:1234
Scenario: An inspector records a passed inspection
    Given I am logged in to the 'Case Management' app as 'Inspector'
    And an inspection is assigned to me
    When I record the inspection outcome as 'Passed'
    Then the inspection is completed
    And the related case moves to the next stage

@issue:1234
Scenario: An inspector attempts to record an outcome without an inspection date
    Given I am logged in to the 'Case Management' app as 'Inspector'
    And an inspection without an inspection date is assigned to me
    When I record the inspection outcome as 'Passed'
    Then the inspection isn't completed
    And I'm told that the inspection date is missing
```
