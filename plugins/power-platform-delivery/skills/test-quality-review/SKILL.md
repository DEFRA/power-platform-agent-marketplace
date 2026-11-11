---
name: test-quality-review
description: Reviews automated test code (acceptance steps, hooks and fixtures, integration tests, test data builders, unit tests) for duplication, flakiness, shared state, unclear failures and drift from the project's conventions, and recommends fixes ranked by priority. Use after writing or before merging test automation, when a suite is slow or flaky, or when test code looks duplicated or inconsistent.
---

# Test quality review

Intended for all agents (it's used most by `quality-engineer`, and by `developer` reviewing unit tests). Load `power-platform-standards` first. This skill reviews and recommends. It doesn't write tests (`acceptance-testing`, `integration-testing`, `scenario-builder`), diagnose a failing test (`test-failure-triage`), scope a change's impact (`test-impact-analysis`) or change business intent.

The standards to review against are in [common-conventions.md](../test-foundations/references/common-conventions.md), [anti-patterns.md](../acceptance-testing/references/anti-patterns.md) and the skills named above. A project's own established conventions count as the standard where they differ.

## Review dimensions

For each, look for the indicator and recommend the paired fix.

| Dimension | Indicator | Fix |
| --- | --- | --- |
| Duplication | Near-identical steps, fixtures, events, fakers or helpers | One reusable, parameterised version |
| Determinism | Fixed delays, ordering between tests, time or random data that isn't controlled | A bounded retry on the condition, and independent tests |
| Isolation | A shared user, record or client. Reliance on leftover data. Roles assigned in a test | A user from the pool and data from builders, per test |
| Portability | Hard-coded URLs, IDs, user names or app names | Configuration, builder outputs or seed data |
| Setup | Direct client calls where a builder event exists. Setup inline in UI steps | Extend or add a builder event |
| Persona | An administrator or the application user where a persona fits. More privilege than needed | The least privileged persona that meets the precondition |
| Separation of concerns | Business rules coded in automation | Raise with `product-analyst`. Automation asserts behaviour |
| Scenario integrity | A feature file edited to fit an implementation defect | Escalate. Don't accept the workaround |
| Production boundary | Production code changed in a test-authoring task | Escalate to `developer` |
| Assertions | Not FluentAssertions. Ungrouped assertions. Assertion exceptions in setup. No `because` | See [common-conventions.md](../test-foundations/references/common-conventions.md) |
| Diagnostics | A null logger. Unlogged requests. Failures that don't say what or which record | Log requests with identifying values. Domain-language errors |
| Naming and structure | Names and layout that differ across the suite | Align with the existing convention |
| Run cost | A scenario or test that is slow for what it proves, or a cosmetic check run as a deployment gate | A cheaper layer: a unit or integration test, or a manual check (see `bdd-scenarios`) |

## Procedure

1. **Scope.** Take the files, project or estate you're asked to review. For a pull request, review the changed test code and what it reuses.
2. **Scan** each dimension.
3. **Record each finding** with its location, dimension, why it matters and a concrete recommendation.
4. **Rank.** Duplication, isolation and diagnostics come first: they multiply across every future test. Say which findings are existing debt and which the change introduced.
5. **Hand the findings back** to the calling agent or the user. Flag a recommendation that needs a broad or disruptive refactor for explicit sign-off. Don't do it unprompted.

## Output

A findings table: **Location** · **Finding** · **Dimension** · **Recommendation** · **Priority** (High, Medium or Low). Write "None identified" when there's nothing, rather than leaving it out.

## Escalation

- A feature file changed to mask a defect goes to `product-analyst` (the scenario) or `developer` (the production defect). Don't accept the workaround.
- A contract the tests assume that isn't documented goes to `solution-architect`.
