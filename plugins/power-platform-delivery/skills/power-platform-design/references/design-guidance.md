# Design guidance by area

Consider each area the change touches, and say which don't apply and why.

| Area | Consider |
| --- | --- |
| Dataverse | Tables, relationships, choices, and calculated and rollup columns. Avoid customising shared or out-of-the-box tables without need. |
| Security model | Business units, security roles, teams, column-level security and least privilege |
| Environments and tenants | How the change behaves in work item, test and static environments, and any cross-tenant or multi-environment needs |
| Integration | Connectors, custom connectors, virtual tables and API patterns. Prefer platform-native options. |
| Power Automate | Whether the logic can run asynchronously, trigger scoping, error handling and connector licensing |
| Copilot Studio | Whether a conversational or AI-based approach would reduce effort or improve the outcome, and its governance and data implications |
| Power Pages | Security for external users, authentication and the content model |
| Licensing | Per-user and per-app licences, premium connectors and add-on capacity |
| Capacity and scale | API limits, storage and throughput |
