---
name: bdd-scenarios
description: Decides which acceptance criteria are worth automating as BDD scenarios, then writes them as Gherkin feature files that reuse the project's existing steps and scenarios and follow its persona login and folder conventions. Reports coverage, gaps and ambiguities. Use when turning user stories or acceptance criteria into scenarios, or when reviewing feature files.
---

# BDD scenarios

Intended for `product-analyst` and `quality-engineer`, but usable by anyone. Load `power-platform-standards` first. This skill writes `.feature` files. Step definitions and test code are covered by `acceptance-testing`.

| Reference | Load it when |
| --- | --- |
| [scenario-style.md](references/scenario-style.md) | Writing or reviewing scenarios: structure, names, tables, tags and an example |
| [personas-and-layout.md](references/personas-and-layout.md) | Choosing the login step and persona, or deciding where a feature file goes |

## Principles

- **Every scenario is a deployment gate.** Scenarios run in pull request validation and after each deployment (see [alm.md](../power-platform-design/references/alm.md)), so one failure blocks promotion. Write them sparingly, for business-critical behaviour and the negative paths that must never regress.
- **Behaviour, not implementation.** Describe what the system does, in business language a non-technical stakeholder can follow.
- **Reuse before writing.** Reuse an existing step whose wording and behaviour genuinely match, and extend an existing scenario rather than write a near-duplicate. Don't force-fit a step that misrepresents the scenario.
- **Independent and simple.** Each scenario sets up its own state and doesn't rely on another. Prefer several simple scenarios to one complex one.

## Decide what to automate

Assess each acceptance criterion before writing any Gherkin:

| Classification | Means | Usually |
| --- | --- | --- |
| Business rule | A rule, workflow, calculation, permission or integration behaviour | Scenario recommended |
| Negative path | A failure that would cause material harm if it broke silently, such as data loss, a wrong approval, a security bypass or a financial impact | Scenario recommended |
| Cosmetic | Layout, wording, styling or a minor change to the screen, with no business rule | Not recommended. Suggest a lighter check, such as a manual check or a unit test. |
| Existing coverage | An existing scenario already covers it | Not recommended. Name the scenario. |

For a borderline case, ask: if this scenario failed intermittently, or the screen changed again, would blocking a release be proportionate to the risk? If not, recommend a lighter check. If the impact is unclear, mark the criterion **Needs clarification** and ask. Write scenarios only for criteria marked **Scenario recommended**.

## Procedure

1. **Confirm the source.** Identify the stories or acceptance criteria, fetching a work item through `azure-boards` if you're given one. If the business objective is unclear, ask before going further.
2. **Assess** each criterion as described above.
3. **Index what exists.** Find the acceptance test project with the [project-facts procedure](../power-platform-standards/references/project-facts.md). Then run both scripts with PowerShell 7, once per session. Each writes a YAML index to a temporary file, never inside the repository:
   - [Build-StepIndex.ps1](scripts/Build-StepIndex.ps1) `-StepsPath <step definitions folder>` lists every step binding with its keyword, pattern, file and line;
   - [Build-ScenarioIndex.ps1](scripts/Build-ScenarioIndex.ps1) `-FeaturesPath <features folder>` lists every scenario with its tags, file and line.

   Search the indexes rather than reading every file. Open a source file only when the index doesn't make a binding's behaviour clear. Run a script with `-?` for its parameters.
4. **Write** the happy-path scenarios, then validation and error scenarios, then any edge cases that carry real business or data risk. Follow [scenario-style.md](references/scenario-style.md) and [personas-and-layout.md](references/personas-and-layout.md).
5. **Check coverage.** Map every acceptance criterion to a scenario or to a decision not to automate it. Don't invent criteria.
6. **Save and report.** Write the scenarios to the feature files on disk: the files are the deliverable. Update the work item only when the user confirms.

## Output

1. The applicability table: each criterion with its classification, decision and a one- or two-sentence rationale.
2. Each feature file written or changed, with its path and the scenarios added.
3. Further analysis, writing "None identified" where there's nothing to report:
   - **Coverage**: each criterion and the scenarios that cover it, or why it isn't automated;
   - **Missing scenarios**: behaviour the feature implies that no criterion covers;
   - **Testability concerns**: anything that can't be verified as written, including a missing step binding or persona;
   - **Ambiguities**: vague terms, undefined thresholds or conflicting rules;
   - **Deployment-gate risk**: scenarios whose flakiness or upkeep could block releases out of proportion to the risk, and decisions not to automate that the team should revisit if its risk tolerance changes.
