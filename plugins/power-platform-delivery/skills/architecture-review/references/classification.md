# Classification

Classify before producing any artefact. The result sets the depth of every later step.

## Pattern fit

Search the ADRs and designs for a pattern that governs the area. Where an approved ADR governs it, check the change against that ADR rather than designing afresh.

| Fit | Means |
| --- | --- |
| Fits | An approved pattern or ADR already answers the question |
| Extends | An approved pattern needs extending, in keeping with its direction |
| New | No approved pattern applies |

If the change conflicts with an approved ADR, escalate. Don't classify round the conflict.

## Review level

| Level | Applies when | Artefacts |
| --- | --- | --- |
| 1, pattern conformance | Fits an approved pattern. No material change of direction, and no significant security, integration, licensing or operational impact. | An architecture review summary that references the governing ADRs. No new ADR or design document. |
| 2, pattern extension | Extends an approved pattern in keeping with its direction. Moderate design considerations, with limited security, integration, ALM, licensing or operational impact. | A targeted assessment, a new or updated ADR where justified, and only the design content needed to communicate the change |
| 3, new pattern or strategic change | Introduces a new pattern, changes the solution's direction or has significant cross-solution impact, with significant security, integration, ALM, operational or licensing implications | A full assessment, ADRs, and a solution architecture document with supporting artefacts where justified |

## Complexity

Rate the complexity Low, Medium, High or Strategic, and name the drivers behind the rating:

- the number of systems affected;
- security impact;
- integration complexity;
- licensing impact;
- ALM impact;
- operational impact;
- cross-solution impact;
- data model impact;
- architectural novelty.

A low level with high complexity, or a high level with low complexity, suggests a misclassification. Reconsider both, and state the reconciled result and why.

## Output

Return this block before anything else:

- **Pattern fit**: fits, extends or new, with the governing ADRs.
- **Review level**: 1, 2 or 3, with the reason.
- **Complexity**: Low, Medium, High or Strategic, with the drivers.
- **Artefacts**: the artefacts that are proportionate, from [artefacts.md](artefacts.md).
- **Confidence**: how certain the classification is, and what would change it.
