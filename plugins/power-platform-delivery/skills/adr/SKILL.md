---
name: adr
description: Writes and maintains Architecture Decision Records. Decides when a decision needs one, finds the project's ADR folder, numbers and fills the template from the architecture review, supersedes rather than duplicates, and keeps the index and the set consistent. Use when recording, updating, superseding or checking an architectural decision.
---

# Architecture Decision Records

Intended for `solution-architect`, but usable by anyone. Load `power-platform-standards` first. Approved ADRs rank second in its source-of-truth order, so they must stay accurate and consistent. The content of a decision comes from `architecture-review`. This skill records it.

| Asset                                     | Use it when       |
| ----------------------------------------- | ----------------- |
| [adr-template.md](assets/adr-template.md) | Writing a new ADR |

## When to write one

Write an ADR for a lasting decision that others must follow, such as:

- a new pattern, or an extension of an existing one;
- an implementation pattern that others will copy;
- a new dependency between solutions;
- a trade-off with a lasting cost;
- a security or integration approach;
- a plug-in that changes the behaviour of a managed action.

A change that conforms to an existing pattern (review level 1) references the ADR that governs it instead.

## Status

| Status     | Means                                                  |
| ---------- | ------------------------------------------------------ |
| Proposed   | Drafted and waiting for a decision. Not authoritative. |
| Accepted   | Approved, and authoritative                            |
| Superseded | Replaced by a later ADR, which it links to             |
| Deprecated | No longer applies, and has no replacement              |

Only Accepted ADRs are authoritative. A person accepts an ADR: never accept your own. Leave a decision with Medium or Low confidence as Proposed, and say what would raise the confidence.

## Procedure

1. **Locate the folder.** Find the project's ADRs with the [project-facts procedure](../power-platform-standards/references/project-facts.md). If the project has none, propose a folder and confirm it with the user.
2. **Search first.** Read the existing ADRs on the subject. Update a Proposed ADR, or supersede an Accepted one, rather than write a duplicate.
3. **Number it.** Copy the template to the next free number, named `NNNN-kebab-case-title.md`, such as `0004-record-inspection-outcomes.md`. Follow the project's naming if it differs.
4. **Fill every section** from the `architecture-review` output. Write "None identified" rather than leave a section empty.
5. **Supersede in both directions.** When the new ADR replaces an old one, set the old one to Superseded and link each to the other.
6. **Keep the set consistent.** Check the decision against the other Accepted ADRs. Raise any conflict with the user for a decision. Never resolve it silently.
7. **Update the index.** Add or update the ADR's row in the folder's index, such as a README table with Number, Title, Status and Date columns. Follow the existing index if there is one.

## Output

Report each ADR written or changed, with its number, title and status. List any conflicts raised and the decisions waiting for a person to accept them.
