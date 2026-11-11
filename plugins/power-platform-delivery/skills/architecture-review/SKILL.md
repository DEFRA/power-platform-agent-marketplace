---
name: architecture-review
description: Assesses the architectural impact of a work item or an existing design. Classifies pattern fit, review level and complexity, compares options including a lower-code one, assesses non-functional requirements, risk and debt, checks fitness and traceability, and produces proportionate artefacts. Use when reviewing a requirement or design, or recommending an architectural approach.
---

# Architecture review

Intended for `solution-architect`, but usable by anyone. Load `power-platform-standards` first. This skill drives the review. It uses `power-platform-design` for Power Platform placement and ALM fit, `adr` to record decisions and `azure-boards` to read and comment on work items.

| Reference | Load it when |
| --- | --- |
| [classification.md](references/classification.md) | Deciding the pattern fit, review level, complexity and the artefacts the review needs |
| [options.md](references/options.md) | Generating and comparing options, justifying reuse, or stating a recommendation and its confidence |
| [risk-and-debt.md](references/risk-and-debt.md) | Assessing non-functional requirements, risks, technical debt and architecture debt |
| [artefacts.md](references/artefacts.md) | Checking fitness and traceability before handover, or writing an artefact |

## Principles

- **Decisions first.** Approved ADRs come before your own judgement. Reuse or extend an approved pattern before proposing a new one.
- **Proportionate.** Scale the effort and the artefacts to the review level. A level 1 change gets a short summary, not a document set.
- **Options, not assumptions.** Compare genuine alternatives, always including a lower-code one. Challenge complexity the requirement doesn't need.
- **Explicit confidence.** Rate every significant recommendation and say why, as [options.md](references/options.md) describes.
- **Incremental.** Recommend the minimum viable increment that proves the approach, and say what's deferred.
- **Cost-aware and outcome-aligned.** Weigh licensing, capacity, build and support cost against the business outcome.
- **Never absorb problems.** Surface gaps, conflicts and risks with an owner rather than design round them.

## Procedure

1. **Gather context.** Read the work item and its links through `azure-boards`. Locate the project's architecture records (ADRs, design documents and the deprecation log) with the [project-facts procedure](../power-platform-standards/references/project-facts.md). Read the ADRs and designs for the area and the components the change touches. Note where the implementation already diverges from an ADR.
2. **Check readiness.** If the requirement is too unclear to assess, stop and list the questions. Don't design round a gap.
3. **Classify.** Decide the pattern fit, review level and complexity, as [classification.md](references/classification.md) describes. The result sets the depth of every later step.
4. **Compare options** and make a recommendation, as [options.md](references/options.md) describes.
5. **Design the Power Platform fit.** Use `power-platform-design` to place the components, plan configuration data and changes to existing components, and write the ALM considerations.
6. **Assess quality, risk and debt**, as [risk-and-debt.md](references/risk-and-debt.md) describes.
7. **Record decisions.** Use `adr` for each lasting decision. A level 1 change references the ADR it conforms to instead.
8. **Check and assemble.** Run the fitness checklist in [artefacts.md](references/artefacts.md), then write the artefacts the classification calls for.
9. **Link back.** When the user agrees, commit the artefacts on the work item branch (see `commit-and-pull-request`) and summarise the outcome in a work item comment through `azure-boards`.

To review an existing design or implementation, follow the same steps against it and produce a design review report.

## Escalate

Stop and raise these with the user rather than decide them yourself:

- an ambiguous or contradictory requirement;
- a conflict with an approved ADR, or an implementation that diverges from one;
- a recommendation with Medium or Low confidence;
- a risk with high likelihood and high impact but no owner or mitigation;
- architecture debt classified as Accepted or Unknown without a rationale;
- a non-functional requirement the design can't meet, which blocks the design;
- an unresolved Critical or High finding in a design review.

## Output

Lead with the outcome: the classification block, the recommendation with its confidence, and anything escalated. Then give the artefacts for the classification, from the templates in [artefacts.md](references/artefacts.md), with the ALM considerations from `power-platform-design` and links to the ADRs. Write "None identified" under a heading rather than leave it out.
