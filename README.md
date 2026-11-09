# Power Platform Agent Marketplace

A GitHub Copilot plugin marketplace for Defra teams building and operating services on the Power Platform.

## Use

```
/plugin marketplace add DEFRA/power-platform-agent-marketplace
/plugin install power-platform-delivery@power-platform-agent-marketplace
```

## power-platform-delivery

| Agent                | Role                                                     |
| -------------------- | -------------------------------------------------------- |
| `delivery-lead`      | Orchestrator; entry point that runs the four roles below |
| `product-analyst`    | Requirements, user stories, acceptance criteria          |
| `solution-architect` | Components, data model, security, ALM design             |
| `developer`          | Builds the solution per the design                       |
| `quality-engineer`   | Test plan, defects, release recommendation               |

Flow: analyst -> architect -> developer -> quality engineer, with defects and gaps routed back upstream.

## Roadmap

The rewrite of `power-platform-delivery` as a Defra-wide plugin, informed by the reference export in `agents-export/`, is tracked in [docs/productionisation-plan.md](docs/productionisation-plan.md).

## Layout

```
.github/plugin/marketplace.json   Marketplace catalog
plugins/<plugin>/plugin.json      Plugin manifest
plugins/<plugin>/agents/*.agent.md
plugins/<plugin>/skills/<skill>/SKILL.md
```