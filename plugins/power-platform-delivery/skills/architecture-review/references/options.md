# Options

For a level 1 change, restate the governing pattern instead of generating options. Where an ADR already evaluated options for the area, start from its evaluation and re-evaluate only what has changed.

## Enumerate

Treat the obvious approach as one candidate, not a foregone conclusion. Include:

- the obvious approach;
- at least one lower-code, simpler or configuration-driven alternative that uses what the platform already has;
- an AI or agent-based alternative, only where it genuinely fits the business problem and has a business, operational and cost case. Never add one just to look thorough.

Scale the number of options and the depth of comparison to the classification.

## Compare

Compare the options on governance fit, security, scalability, maintainability, supportability, licensing, cost and technical debt. This comparison is for choosing between options. The full assessment of the chosen one is in [risk-and-debt.md](risk-and-debt.md).

## Reuse

For each option, decide whether it's a reusable capability, an extension of an existing one, or specific to this requirement.

- Prefer reuse through configuration to reuse through frameworks, such as a generic engine or a plug-in framework. The Power Platform forms of reuse are in `power-platform-design`.
- Justify reuse by a reasonable expectation of future consumers, not by possibility. Don't build speculative frameworks or abstractions.
- When you recommend reuse, state why it's valuable here, who the expected consumers are, the extra complexity, the operational and maintenance implications, and why a simpler requirement-specific design wasn't chosen.

## Confidence

| Rating | When                                                                                                        |
| ------ | ----------------------------------------------------------------------------------------------------------- |
| High   | Validated requirements, established patterns, approved ADRs, enough context and little material uncertainty |
| Medium | Sound, but relies on assumptions, incomplete information or areas to validate during delivery               |
| Low    | Requirement gaps, architectural unknowns, external dependencies or open decisions materially affect it      |

Explain the main factors behind the rating, and separate confirmed facts from assumptions. For Medium or Low, recommend how to raise confidence, such as a spike or a question for the product owner. Still give your best recommendation: low confidence calls for transparency, not silence.

## Recommendation

State each recommendation with:

1. **Recommendation**: the approach, stated plainly.
2. **Rationale**: why it best meets the requirement and its constraints.
3. **Alternatives considered**: the other options and why they weren't chosen.
4. **Benefits**: the value it delivers.
5. **Risks**: what could go wrong, and how severe it would be.
6. **Assumptions**: what's taken as true pending confirmation.
7. **Dependencies**: the systems, teams, solutions and decisions it relies on.
8. **Licensing impact**: changes to licences, connector use or entitlements.
9. **Operational considerations**: monitoring, support and maintenance once live.
10. **Decision confidence**: the rating, the reasons and what would raise it.
