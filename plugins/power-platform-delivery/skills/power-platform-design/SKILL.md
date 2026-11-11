---
name: power-platform-design
description: Places a change on the Power Platform and fits it to the ALM lifecycle. Covers component placement, the platform areas a design must consider, how configuration data reaches every environment, changing or retiring components without breaking dependents, and the ALM considerations for a design. Use when designing or reviewing a Power Platform change.
---

# Power Platform design

Intended for `solution-architect`, but usable by anyone. Load `power-platform-standards` first: its low-code, future-proofing and ALM rules apply throughout and aren't repeated here. `architecture-review` uses this skill for the Power Platform part of a review.

| Reference                                                   | Load it when                                                                                               |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [design-guidance.md](references/design-guidance.md)         | Deciding what to consider in each platform area the change touches                                         |
| [alm.md](references/alm.md)                                 | Checking how the change moves through the power-pipelines lifecycle and what the design must do to fit it  |
| [non-breaking-change.md](references/non-breaking-change.md) | Adding configuration or reference data, or changing or retiring a component that something else depends on |
| [deprecated-components.md](assets/deprecated-components.md) | Starting a deprecation log for a project that doesn't have one                                             |

## Placement principles

- **Reuse before create.** Extend an existing table, flow, integration, API, plug-in or connector before proposing a new one, and justify any new component.
- **Dataverse first.** Use declarative Dataverse capabilities before plug-ins, custom code, external services, separate databases or another integration platform. Introduce those only when the platform can't reasonably meet the requirement.
- **Synchronous logic.** Cloud flows run asynchronously, after the save. For server-side logic that must run within the save, prefer table-scoped business rules, then real-time workflows, then actions or custom workflow activities, then plug-ins. When code is justified is covered in [dataverse-plugins](../dataverse-plugins/SKILL.md).
- **Decompose processes.** Break an end-to-end process into rules, processes and actions rather than one large flow or workflow, so behaviour such as validation applies wherever the data or action is used.
- **Reuse through configuration.** Prefer configuration tables to hard-coded behaviour, environment variables to environment-specific customisation, reusable child flows to duplicated logic, and Custom APIs for reusable service boundaries. Don't build plug-in frameworks, generic engines or abstraction layers for requirements nobody has.
- **Build to contract.** Never break an integration, a contract, a managed action or a dependent solution (see [non-breaking-change.md](references/non-breaking-change.md)).

## Procedure

1. **Scope.** Decide which areas in [design-guidance.md](references/design-guidance.md) the change touches. Say which don't apply, and why.
2. **Place the components.** Apply the principles above, and name the solution that owns each new or changed component.
3. **Plan configuration data.** For each new configuration or reference record, choose its deployment path from [non-breaking-change.md](references/non-breaking-change.md).
4. **Plan changes and retirements.** For each component that's changed or retired, follow [non-breaking-change.md](references/non-breaking-change.md) and update the project's deprecation log. Find the log with the [project-facts procedure](../power-platform-standards/references/project-facts.md), or start one from the [template](assets/deprecated-components.md).
5. **Fit the lifecycle.** Check the design against the checklist in [alm.md](references/alm.md).
6. **Write the ALM considerations** below. Flag placement decisions with lasting consequences for an ADR, such as a new pattern or a plug-in on a managed action.

## ALM considerations

Cover each point. Write "Not affected" where one doesn't apply.

- **Solution boundaries and layering**: the solution that owns each component, and any new dependency between solutions.
- **Managed and unmanaged**: anything that relies on unmanaged changes outside the work item's development environment. Normally nothing does.
- **Package composition and import order**: any solution added to the package, and where it sits in the order.
- **Environment strategy and values**: environment variables, connection references and per-environment import configuration.
- **Deployment complexity and release**: anything that makes the deployment riskier or needs coordinating, such as a data migration or a release with another team.
- **Cross-solution dependencies**: the solutions that depend on the change, and how they're protected.
- **Configuration data**: the deployment path chosen for each new record.
- **Non-breaking change and deprecation**: what's marked obsolete, and its deprecation log entry.

## Escalate

- A deployment step that would have to be done by hand. It blocks the design until it's redesigned.
- A component to retire that still has dependents. Don't mark it obsolete.
- A requirement that conflicts with these principles, such as code where configuration would do. Set out the compliant alternative and let the user decide.
