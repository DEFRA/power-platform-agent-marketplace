---
name: power-platform-standards
description: Shared house rules for Power Platform delivery - source precedence, low-code first, future-proof solutions, ephemeral environments, zero manual deployment steps, the Definition of Done and how to find project facts. Load first, for every agent and any task in a Power Platform repository, before role-specific skills.
---

# Power Platform standards

Intended for all agents (and anyone working by hand). These are the rules every other skill assumes. Skills add procedure; they don't repeat what is here.

## Source of truth

When sources conflict, use the first that applies:

1. Explicit user instructions
2. Approved Architecture Decision Records (ADRs)
3. Approved design documentation
4. Repository standards and conventions (including this skill)
5. Existing implementation
6. Assumptions

Don't override a documented decision without naming the conflict. Don't treat existing code as authoritative when a decision is documented. Make assumptions explicit and don't present them as facts.

## Working practices

- Read existing artefacts before creating new ones. Reuse patterns before introducing new ones.
- Prefer clarity, simplicity and maintainability over cleverness or premature optimisation.
- Make incremental changes. Don't rewrite working solutions or refactor at scale without justification.
- Don't invent requirements. Where information is missing, say so, set out the options and recommend one.
- Apply least privilege, never expose or hard-code secrets, and raise security doubts explicitly.
- Stay within your role and hand off to the specialist agent when the work is theirs (for example design questions to `solution-architect`, tests to `quality-engineer`).
- Verify before calling work done. Implementation alone is not completion.
- Write in clear British English.

## Power Platform approach

**Low-code first.** Business logic lives in declarative components: workflows, actions, business process flows, cloud flows and business rules. Encapsulate atomic processes as actions. Write code only when it is **highly reusable and unlikely to change**, such as platform extensions rather than business processes. Plug-ins and custom workflow activities are as configurable, generic and granular as possible.

Plug-in steps are rarely right. Use them only to change the behaviour of managed actions or to react to messages that workflows and flows don't support. They lack the scoping of workflows and flows and the inputs and outputs of actions and custom workflow activities.

**Low-code build stays with the human developer.** Agents state what to change in the development environment, in this order: tables, columns, processes, flows, business rules, then plug-in and web resource registrations. Agents hand-edit only the customisation XML that Microsoft supports editing (ribbon, site map, forms and dashboards, views). See the `customisation-xml` skill.

**Future-proof solutions.** An environment can hold many solutions over its lifetime, so:

- Avoid organisation-scoped processes or plug-in steps on out-of-the-box messages for out-of-the-box tables. They can stop other parts of the business reusing those tables.
- Don't customise managed forms or views. Create new forms and views for your app.

## Environments and ALM

Projects follow the ALM lifecycle of [power-pipelines](https://github.com/ewingjm/power-pipelines). The `power-platform-design` skill holds the detail (`references/alm.md`). What it means for every agent:

- **Ephemeral environments.** Each work item gets its own development environment, and pull request validation deploys to a fresh test environment. Never assume a shared dev environment. Nothing of value may live only in an environment: it must be in Git or in the package's data.
- **Solution metadata is synced, never hand-written**, apart from the customisation XML above. Pro-code is mapped into the solution at build time.
- **Zero manual deployment steps.** Every change must deploy through the package alone. Environment differences go in import configuration, not code.
- **QA shifts left.** Acceptance and integration tests run unattended against a freshly deployed environment, and build their own data.
- **Commits drive versioning.** Titles follow Conventional Commits (see the `commit-and-pull-request` skill).

Agents design and work within this lifecycle. They don't run or edit pipelines. If a project lacks a power-pipelines feature that would help, recommend it and leave the change to the human.

## Definition of Done

Work is complete only when:

- Requirements and acceptance criteria are satisfied.
- Quality checks and tests have run, and any failures are explained.
- Documentation is updated where behaviour, architecture, deployment, configuration or user processes changed. Record why a decision was made, not only what.
- The change deploys with no manual steps.
- Risks, dependencies and outstanding assumptions are written down.

## Project facts and stack

- Discover project facts (solutions, prefixes, projects, base branch and so on) from the repo, confirm them with the user, and store only what can't be discovered. Never hard-code them. See [project-facts.md](references/project-facts.md).
- The technology stack, versions and test framework preferences are recorded once in [stack.md](references/stack.md). A project's existing conventions and frameworks take precedence over the defaults there.
- Examples in this plugin use a neutral domain: Case, Applicant and Inspection, with the publisher prefix `abc_`.
