---
name: acceptance-testing
description: Automates approved Gherkin scenarios for a model-driven app with Reqnroll step bindings, hooks and Power Playwright, building every precondition through ScenarioBuilder. Use when scenarios have no automation, when automation must follow changed behaviour, or when a scenario needs a non-functional wording fix to bind reliably.
---

# Acceptance testing

Intended for `quality-engineer`, but usable by anyone. Load `power-platform-standards` first, then `test-foundations` for users, clients and run set-up, and `scenario-builder` for data setup. The `bdd-scenarios` skill decides which scenarios are worth writing and writes the `.feature` files. This skill turns approved scenarios into passing, maintainable automation without changing their business intent.

Acceptance tests run unattended against a freshly deployed environment in pull request validation, and after each deployment (see [alm.md](../power-platform-design/references/alm.md)). A flaky or order-dependent test therefore blocks releases.

| Reference | Load it when |
| --- | --- |
| [standard.md](references/standard.md) | Writing or changing a step class, a transformation or the test layout |
| [power-playwright.md](references/power-playwright.md) | Driving the app: sessions, forms, grids, command bar, waiting |
| [recipes.md](references/recipes.md) | You need a worked step for a common need |
| [anti-patterns.md](references/anti-patterns.md) | Writing or reviewing automation |
| [runtime.md](references/runtime.md) | Touching Reqnroll hooks and their order, login and browser state, tracing or feature-flag tags |

Shared with integration tests, in `test-foundations`: [common-conventions.md](../test-foundations/references/common-conventions.md) (assertions, defensive coding, retries, logging), [users-and-personas.md](../test-foundations/references/users-and-personas.md), [clients.md](../test-foundations/references/clients.md), [configuration.md](../test-foundations/references/configuration.md) and [run-lifecycle.md](../test-foundations/references/run-lifecycle.md).

## Principles

- **Three separate concerns.** Gherkin says what, from a persona's view. Step definitions translate it into data setup or UI actions. ScenarioBuilder creates the Dataverse state without the UI.
- **If an API can set up a precondition, use the API.** Use Power Playwright only for the behaviour under test.
- **Each scenario builds only its own data**, from new records, and depends on nothing another scenario left behind. It must be able to run on its own and in parallel.
- **Follow the project.** Extend and reuse its step naming, fixtures, session handling and builders before introducing new ones. A project's own conventions beat the defaults here.

## Procedure

1. **Confirm the source.** The approved `.feature` file is the source of truth for intent. Don't reinterpret it to make automation pass. If it isn't approved, or it's missing, hand it to `product-analyst` instead of writing one.
2. **Find the project's pieces** (see [project-facts.md](../power-platform-standards/references/project-facts.md)): the acceptance test project, the shared test-data project, the app name from `AppModule.xml` and the persona file. Confirm them with the user.
3. **Check what exists.** Search the step bindings, hooks, models, services, transformations and the shared test-data project for something that already does the job. `bdd-scenarios` has scripts that index the steps and scenarios.
4. **Implement or update** the step bindings, hooks, services and transformations, following [standard.md](references/standard.md). Build preconditions with `scenario-builder`: if no event covers one, add an event there instead of writing setup in a step class.
5. **Apply a permitted refinement** to a scenario only where needed (below), never as a substitute for an amendment.
6. **Run the scenarios** and read the results. A scenario passes on its own and alongside the rest. If you can't run them here, say so plainly. Don't assume success.
7. **Hand on what you find.** Failing runs go to `test-failure-triage`. Maintainability concerns go to `test-quality-review` instead of an unrequested broad refactor.

## Permitted scenario refinements

You may make limited, non-business changes to improve how reliably a scenario binds:

- quote string parameters and standardise parameter notation;
- reword to match an existing step binding;
- remove wording that makes bindings ambiguous, or detail the scenario's context already implies;
- align with the repository's conventions.

Each must preserve business intent, criteria coverage, readability for stakeholders and meaning. Report every one you make and why.

## Escalation

Never change business requirements, acceptance criteria, rules, expected behaviour or scope, and never edit a feature file to compensate for a defect in the implementation.

- If automation exposes an ambiguity, a contradiction or a gap, explain it, recommend a change and return the scenario to `product-analyst`.
- If the test passes but the behaviour disagrees with an ADR or design, raise it with `solution-architect`.
- If the system under test is wrong, report it as a defect for `developer`. Don't work around it in the test.
- If the scenarios need a persona or environment that doesn't exist, say so. Adding a persona is test work. Environment provisioning belongs to the human who owns the pipelines.

## Output

- The step bindings, hooks, services and transformations you changed, in the right projects.
- Whether the scenarios were run and passed, or why they weren't.
- A short summary: which scenarios you automated or updated, which existing steps, fixtures and builders you reused, any refinements and why, and any escalations.
