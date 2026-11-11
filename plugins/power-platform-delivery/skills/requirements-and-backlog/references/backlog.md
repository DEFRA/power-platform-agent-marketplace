# Backlog

## Hierarchy

| Level              | Describes                                                                   | Example                                  |
| ------------------ | --------------------------------------------------------------------------- | ---------------------------------------- |
| Business objective | The outcome the organisation wants                                          | Applicants get inspection results sooner |
| Epic               | A large body of work towards the objective, often spanning several releases | Inspection outcomes                      |
| Feature            | A capability users get, deliverable within a release                        | Record inspection outcomes               |
| User story         | One vertical slice of a feature, small enough for a sprint                  | Record a passed inspection               |

Use the work item types configured for the project (see `azure-boards`), and link each item to its parent.

## Splitting

Split a story that's too big for a sprint, has too many acceptance criteria or mixes several outcomes. Split by:

- **Workflow step**: create a case, then assign it, then close it.
- **Business rule variation**: a passed inspection, then a failed one.
- **Role**: what an inspector does, then what a manager does.
- **Data variation**: one inspection type, then the others.
- **Simple first**: the main path, then the exceptions.

Never split by technical layer, such as the table, the form and then the flow. Each slice must work end to end.

## Story format

- **Title**: a short verb phrase, such as "Record a passed inspection".
- **Story**: `As a <role>, I want <capability>, so that <benefit>.` Use a real role from discovery, not "user". The benefit states the value rather than repeating the capability.

## Acceptance criteria

- Write each criterion as Given, When and Then, or as a plain rule, whichever is clearer.
- Make each one testable, with an observable outcome that passes or fails.
- Cover the main path, the important alternatives and the failures, such as validation, permissions and missing data.
- Describe behaviour, not the screen layout or the implementation.
- Aim for three to seven. More suggests the story should be split.
- Number them so they can be referred to.

## Example

**Record a passed inspection**

As an inspector, I want to record that an inspection passed, so that the applicant's case can move to the next stage without waiting for a manual review.

1. Given an inspection in progress, when the inspector records the outcome as passed, then the inspection is completed with that outcome and today's date.
2. Given an inspection that has just passed, when it's completed, then the related case moves to the next stage.
3. Given an inspection with no inspection date, when the inspector tries to record the outcome, then the outcome isn't saved and the inspector is told that the date is missing.

## Output

For a breakdown, use these headings:

1. Epic
2. Features
3. User stories, each with its title, story, acceptance criteria and parent
4. Assumptions
5. Dependencies
6. Sequencing
7. Remaining questions

Write "None identified" under any heading with nothing to report.
