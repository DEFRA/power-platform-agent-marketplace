---
name: test-failure-triage
description: Diagnoses a failing or flaky automated test, classifies the root cause as a requirement defect, scenario defect, test implementation defect, production defect or environment issue, and names the right owner to route it to. Use whenever a test fails, in a pull request run or locally, and the cause isn't yet known.
---

# Test failure triage

Intended for all agents (it's used most by `quality-engineer`, and by `developer` when a pull request fails). Load `power-platform-standards` first. This skill classifies and routes. It doesn't fix. The owner of the classified cause does the fix.

Never assume a production defect by default, and never rewrite a test, step binding or feature file to force a pass.

## Classification and routing

| Category                   | Means                                                                                        | Route to                                                                                           |
| -------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Requirement defect         | The requirement is wrong, ambiguous or incomplete                                            | `product-analyst`                                                                                  |
| Scenario defect            | The scenario misstates a correct requirement                                                 | `product-analyst`                                                                                  |
| Test implementation defect | The automation (step, fixture, event, integration test) doesn't implement a correct scenario | `quality-engineer`, using `acceptance-testing`, `integration-testing` or `scenario-builder`        |
| Production defect          | The system doesn't behave as the correct requirement and scenario say                        | `developer`                                                                                        |
| Environment issue          | The cause is the environment, its configuration, users or data, not code                     | The human who owns the environments (they own the pipelines' environments). Agents don't fix these |

A failure from a contract disagreement, such as a test that fails because the implementation and an ADR differ, goes to `solution-architect` to decide which is right.

## Procedure

1. **Gather evidence.** Take what exists and don't ask for what you can read:
   - the test output, stack trace and the logs from setup and steps (ScenarioBuilder logs every request, so find the last one that succeeded);
   - the Playwright trace for a failed acceptance scenario, and plug-in trace logs for a back-end failure;
   - the scenario or test and its acceptance criteria;
   - which environment it ran in: a fresh pull request environment, a static environment or a local one;
   - recent related changes (`test-impact-analysis`).
2. **Locate the failure.** Did setup, the action or the assertion fail? A failure in a `Given` is rarely a production defect. A failure in a `Then` after a clean setup is.
3. **Test each hypothesis against the table.** Rule categories in or out with the evidence. [symptoms.md](references/symptoms.md) lists signs that point to each, including those of flaky tests.
4. **For a flaky test**, rerun it alone and then with its neighbours. A test that passes alone and fails in a run points to shared state, a shared user or a wait. Classify the cause, not the flakiness.
5. **State the most likely cause,** with the evidence for it and what would change your mind.
6. **Route it.** Say who owns it and what they need from you.

## Output

For each failing test, one row:

| Test | Classification | Evidence | Owner | Confidence |
| ---- | -------------- | -------- | ----- | ---------- |

Confidence says how sure you are and what extra evidence would confirm or change the classification. When several tests fail from one cause, group them under it, and say so.
