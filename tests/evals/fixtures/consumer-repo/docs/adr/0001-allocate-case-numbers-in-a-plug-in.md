# 0001. Allocate case numbers in a plug-in

- **Status**: Accepted
- **Date**: 2026-03-02
- **Related work items**: AB#1001 Case numbering
- **Related ADRs**: None
- **Decision confidence**: High, because the number must be allocated inside the transaction that submits the Case

## Context

Every submitted Case needs a unique, readable number. Case officers quote it to Applicants by phone. Facts: Cases are submitted from the app and by import. Assumption: volumes stay under 500 Cases a day.

## Decision

We will allocate the case number in a pre-update plug-in on `abc_case`, using a sequence row, so that every submission path gets a number inside the same transaction.

## Alternatives considered

| Option               | Description                                  | Why it wasn't chosen                                        |
| -------------------- | -------------------------------------------- | ----------------------------------------------------------- |
| Auto-number column   | Use the platform's auto-number column type   | The agreed format needs a year prefix and a reset each year |
| Real-time workflow   | Set the number in a synchronous workflow     | Can't run in the transaction, so imports could miss it      |

## Consequences

### Positive

Every submitted Case has a number from the moment it is submitted.

### Negative

A plug-in to maintain, and one extra row that every submission updates.

### Cost impact

None identified.

### Impact on other solutions and environments

None identified.

### Debt impact

- **Technical debt**: Neutral, one small plug-in.
- **Architecture debt**: Neutral, follows the standard plug-in pattern.

## Open questions and assumptions

None identified.
