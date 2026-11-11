---
name: integration-testing
description: Designs and writes integration tests that exercise Dataverse and its integration boundaries directly through the API, checking the implementation against the documented contract. Builds data with ScenarioBuilder, acts as the right persona and asserts with FluentAssertions. Use when a back-end change needs coverage below the UI, such as plug-ins, flows, security or data transformations.
---

# Integration testing

Intended for `quality-engineer`, but usable by anyone. Load `power-platform-standards` first, then `test-foundations` for users, clients, run set-up and the shared conventions, and `scenario-builder` for the data setup.

Integration tests check real system boundaries: Dataverse (tables, plug-ins, workflows, actions, security), cloud flows, Azure integrations such as Logic Apps and Service Bus, and external APIs. They confirm that the implementation honours its intended contract, not incidental detail. They are lighter than acceptance tests: no UI, no Gherkin and no persona-driven navigation, so they are cheaper and quicker and can check back-end changes at a finer grain. Acceptance tests remain necessary for end-to-end behaviour through the UI. Use both, and don't substitute one for the other.

Like acceptance tests, they run unattended against a freshly deployed environment (see [alm.md](../power-platform-design/references/alm.md)) and so must build all their own data.

## Core rule

Every test has three separate parts:

1. **Arrange.** Build the Dataverse state with ScenarioBuilder.
2. **Act.** Perform the behaviour under test through a real client, as the persona or user that owns the behaviour, using the API call a real caller would make.
3. **Assert.** Check the resulting state with FluentAssertions, with a `because` reason.

If you're creating data, use ScenarioBuilder. If you're exercising or verifying behaviour, use the client directly. A worked test is in [example.md](references/example.md).

## Conventions

Shared with acceptance tests, in `test-foundations`: [common-conventions.md](../test-foundations/references/common-conventions.md) (assertions, defensive coding, retries, logging), [users-and-personas.md](../test-foundations/references/users-and-personas.md), [clients.md](../test-foundations/references/clients.md), [configuration.md](../test-foundations/references/configuration.md) and [run-lifecycle.md](../test-foundations/references/run-lifecycle.md), which maps the run stages to MSTest's initialise and cleanup methods. Specific to integration tests:

- **Test classes** are named `<Entity>Tests` for behaviour of a table, or `<Action>Tests` for an unbound action with no owning table. **Test methods** are named `Action_Condition_Expectation`, such as `Close_WhenCaseHasAnOpenInspection_CancelsInspection`.
- **Personas.** Use the client for the persona that owns the behaviour. Don't default to an administrator or the application user unless the behaviour is itself service-level. If it depends on a specific user, such as a record's owner, get a client for that user's ID.
- **Scope the client** to the Act and Assert, in a `using` block, if the test owns it. A persona client from the factory is owned by the factory (see [clients.md](../test-foundations/references/clients.md)).
- **Read results from the scenario** for values the builder already captured. Query Dataverse again only for state the action changed.
- **Eventually consistent work**, such as an asynchronous plug-in step or a flow, is polled with a bounded retry, never a fixed delay.
- **Independent tests.** Each builds its own data and runs alone and in parallel, with no dependency on another test's leftovers.
- **Frameworks follow the project.** MSTest and FluentAssertions are the defaults (see [stack.md](../power-platform-standards/references/stack.md)). A project's own framework wins.

## Procedure

1. **Name the boundary and the contract.** Identify the component interaction, system boundary or rule you're validating. Read the relevant ADRs and design documents, which the project-facts procedure finds (see [project-facts.md](../power-platform-standards/references/project-facts.md)), so the assertions state the intended behaviour.
2. **Decide the layer.** If the behaviour is only visible through the UI, it's an acceptance test (`acceptance-testing`). If it is logic in a plug-in's own services, a unit test (`dataverse-plugins`) is cheaper. Use an integration test for what crosses the platform boundary.
3. **Find the pieces.** Locate the integration test project, the shared test-data project and the persona list, and confirm them with the user. Search for an existing test class and builder before writing new ones.
4. **Arrange.** Reuse or extend a ScenarioBuilder event. Never hand-roll records in the test. If no event exists, add one to the shared test-data project with `scenario-builder`.
5. **Write the test** as above, for whichever of these the change touches: component interactions, system boundaries, Dataverse behaviour, integrations, security boundaries (who can and who can't), data transformations and deployment assumptions, such as the configuration or seed data the package deploys.
6. **Run it** and read the output. Say if you couldn't.
7. **Hand on.** A failing run goes to `test-failure-triage`. A maintainability concern goes to `test-quality-review`.

## Escalation

- If the implementation appears to break a documented contract, don't adjust the test to match it. Raise it with `solution-architect` to decide whether the implementation or the contract is wrong.
- If no ADR or design document defines the contract, flag the gap and recommend that `solution-architect` records the decision. Don't assume one.
- If the cause is a production defect, report it for `developer`. Don't work around it in the test.

## Output

- The tests you wrote or changed, in the integration test project, building and passing (or why not).
- A short summary: which boundary and contract you validated, which ADR, design document or work item it follows, and which builders you reused or added.
