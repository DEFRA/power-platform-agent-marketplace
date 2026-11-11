# Non-functional requirements, risk and debt

Scale the depth to the classification. At level 1 or Low complexity, a brief pass over each category is enough. At level 2 or 3, or High or Strategic complexity, assess every impacted category in full and record even minor risks.

## Non-functional requirements

Assess all twelve categories, in this order: security, performance, scalability, availability, maintainability, supportability, observability, auditability, compliance, recoverability, data residency and accessibility (where users see the change). Observability covers monitoring, telemetry, logging, alerting and diagnostics. Assess it in its own right, not as part of supportability.

Rate each category:

- **Impacted**: give the expectation, how the design meets it, and the risks and mitigations.
- **Low relevance** or **Not applicable**: give a one-line reason. Never leave a category out.

A requirement the design can't meet, such as a compliance or data residency requirement the platform can't satisfy, is a blocking risk. Never rate it low relevance.

| Category | Materiality | Expectation | How the design meets it | Risks and mitigations |
| --- | --- | --- | --- | --- |

## Risk register

| Description | Category | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |

The category is technical, security, operational, cost, licensing, technical debt or architecture debt. Write "unassigned" when a risk has no owner yet.

## Debt register

Assess two kinds of debt separately, and report them together:

- **Technical debt**: shortcuts in the implementation.
- **Architecture debt**: structural compromises that affect the wider solution landscape, such as temporary exceptions, duplicate or inconsistent patterns, transitional integrations, deviations from approved standards and legacy constructs kept for compatibility.

| Description | Kind | Rationale | Classification | Review or retirement criteria |
| --- | --- | --- | --- | --- |

Classify each item as Accepted, Deferred, Mitigated, Eliminated or Unknown. Include debt that the change introduces, removes or leaves in place.
