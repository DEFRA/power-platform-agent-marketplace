---
name: test-impact-analysis
description: Works out which scenarios, step bindings, fixtures, integration tests, unit tests and test data a change affects, from the diff against the base branch or from a work item's acceptance criteria, and builds the traceability chain from work item to production code. Use before writing or updating tests, to scope regression risk, or to write a testing impact summary for a pull request.
---

# Test impact analysis

Intended for all agents (it's used most by `quality-engineer` and `developer`). Load `power-platform-standards` first. This skill analyses and reports. It doesn't write or change tests (`acceptance-testing`, `integration-testing`, `dataverse-plugins` and `web-resources` do), diagnose failures (`test-failure-triage`) or review test code (`test-quality-review`).

## Why categories matter

Pull request validation runs only the stages whose inputs changed: the solutions, the package, the web resources and the assemblies (see [alm.md](../power-platform-design/references/alm.md)). Scope the tests the same way, so nothing affected is missed and nothing unaffected is run for show.

## Procedure

1. **Establish the baseline.**
   - Discover the base branch (`git symbolic-ref --short refs/remotes/origin/HEAD`) and diff against it, three-dot, including uncommitted changes: `git diff <base>...HEAD --name-status`, plus `git status --short`.
   - If there's no diff, such as a work item picked up before implementation or tests for existing behaviour, use the acceptance criteria plus the existing tests as the baseline.
   - Record which baseline you used. If neither is enough to scope the change reliably, say so, and present the result as partial.
2. **Categorise what changed**, using the table below. A single change often falls in several categories.
3. **Map to test artefacts** and decide, for each, whether it needs a change, and whether to extend an existing artefact rather than add one.
4. **Build the traceability chain** (below) and call out every broken or missing link. Don't omit one.
5. **Report.**

| What changed                                                                  | Look for impact on                                                                                                                                                                                                       |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Solution metadata: tables, columns, forms, views, ribbon, site map, processes | Scenarios and step bindings that name the affected table, field, command, view or tab. Integration tests for changed processes. Fakers and events that set changed columns (look the columns up with `dataverse-schema`) |
| The early-bound model, regenerated                                            | Fakers and events that use renamed or retyped properties                                                                                                                                                                 |
| Assemblies: plug-ins, custom workflow activities                              | Integration tests across the boundary they change. Unit tests (`dataverse-plugins`). Scenarios that rely on the outcome                                                                                                  |
| Web resources                                                                 | Scenarios on the forms and ribbons that load them. The scripts' own Jest tests (`web-resources`)                                                                                                                         |
| Package: import configuration, seed data, environment variables               | Tests that depend on reference data or environment-specific values. Deployment assumptions                                                                                                                               |
| Security roles, teams or personas                                             | Persona configuration and the scenarios and integration tests that exercise who can and can't act                                                                                                                        |
| The shared test-data project (events, fakers, user pool)                      | Every test that uses a changed event or faker. Both test layers                                                                                                                                                          |
| Feature files, step bindings, hooks                                           | The scenarios they bind. Step reuse elsewhere (search the step index from `bdd-scenarios`)                                                                                                                               |

## Traceability chain

Work item → acceptance criteria → scenario → scenario automation → integration tests → production implementation.

Say what each link is (an ID or a file) or that it's missing. Route a gap to its owner. Don't fill it yourself:

- a criterion with no scenario goes to `product-analyst` (`bdd-scenarios` decides whether it is worth automating);
- behaviour with no ADR or design for the contract under test goes to `solution-architect`.

## Output

- **Baseline:** the mode used, and the base branch and commit if there's a diff.
- **Impact table:** artefact type (scenario, step binding, fixture or hook, integration test, unit test, data asset) · item · change needed · extend or new.
- **Traceability chain,** with gaps called out.
- **Run recommendation:** which categories of tests need to run for this change and why. This is a recommendation. The pipeline decides what it runs.
- "No test impact identified" when that's the answer. Don't leave the section out.
