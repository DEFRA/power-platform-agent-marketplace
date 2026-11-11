# Fitness and artefacts

Check fitness before handing over any artefact. Send a gap back to the step that owns it rather than patch it here.

## Traceability

The chain runs business objective → epic → feature → user story → acceptance criteria → design → ADRs → solution components. Every recommendation, ADR, review report and summary names the work items it came from and the acceptance criteria it satisfies. Say so when a design affects several work items.

## Fitness checklist

| Check                                      | Owned by                               | Fails when                                                                                 |
| ------------------------------------------ | -------------------------------------- | ------------------------------------------------------------------------------------------ |
| Classification                             | [classification.md](classification.md) | No classification is stated, or the artefacts don't match it                               |
| ADR alignment and reuse                    | `adr` and [options.md](options.md)     | A conflicting ADR isn't surfaced, or reuse wasn't considered                               |
| Options and confidence                     | [options.md](options.md)               | A significant recommendation has no alternatives, rationale or confidence rating           |
| Non-functional requirements, risk and debt | [risk-and-debt.md](risk-and-debt.md)   | A category is missing, or a risk or debt item is unclassified                              |
| Configuration data                         | `power-platform-design`                | New configuration or reference data has no deployment path, or a deployment step is manual |
| Non-breaking change                        | `power-platform-design`                | A retired component still has dependents, or the deprecation log wasn't updated            |
| Operations and security                    | [risk-and-debt.md](risk-and-debt.md)   | Support or security isn't addressed for a material change                                  |
| Incremental delivery                       | The review                             | A change delivered in stages has no minimum viable increment                               |
| Acceptance criteria                        | The review                             | An acceptance criterion isn't addressed anywhere                                           |

Don't hand over while any check fails. Record any material divergence between the implementation and the approved architecture, with its impact, its risk and a remediation path.

## Templates

Scale each artefact to the classification. Use only the sections that apply, and say which you left out and why.

**Architecture review summary** (level 1, or a summary at any level): recommendation; alternatives considered; key risks; cost implications; ADR references; approvals needed; decision confidence; open questions.

**Solution architecture document** (level 3, or level 2 where justified): requirement summary and work item links; solution vision and guiding principles; options considered and why the recommendation was chosen; the approach and its components, with context, logical and physical diagrams as needed; how each acceptance criterion and non-functional requirement is met; reusable capability assessment; security design; integration design; ALM considerations; technical and architecture debt impact; risks and mitigations; cost and licensing impact; dependencies and cross-solution impact; operational support; minimum viable increment and incremental plan; decision confidence; open questions and assumptions.

**Reusable capability assessment**: capabilities reused or extended; new reusable capabilities; configuration-driven behaviour introduced; expected future reuse; requirement-specific alternatives considered; the justification for any reusable abstraction; why the approach balances reuse and simplicity.

**Design review report**: findings, each with a severity (Critical, High, Medium or Low), description, impact, recommendation with decision confidence, and priority. Include any divergence between the implementation and the approved architecture.

**Operational support model**: monitoring and alerting, the escalation path, known limitations and any manual or operational processes needed once live.

## Writing

- Lead with the outcome and its impact, then the detail.
- Use clear headings and consistent terms.
- Leave out implementation detail that no acceptance criterion needs.
