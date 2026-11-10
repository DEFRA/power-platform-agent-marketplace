# Power Platform Agent Marketplace

A GitHub Copilot plugin marketplace for Defra teams building and operating services on the Power Platform.

## Use

```
/plugin marketplace add DEFRA/power-platform-agent-marketplace
/plugin install power-platform-delivery@power-platform-agent-marketplace
```

## power-platform-delivery

The plugin is being rewritten, so it currently ships no agents or skills. They are added task by task; see [docs/productionisation-plan.md](docs/productionisation-plan.md) (§3.2 for the target agents).

## Roadmap

The rewrite of `power-platform-delivery` as a Defra-wide plugin, informed by the reference export in `agents-export/`, is tracked in [docs/productionisation-plan.md](docs/productionisation-plan.md).

## Contributing

See the [authoring guide](docs/authoring-guide.md) for the rules every agent, skill and script follows. CI runs the checks on Windows and Linux.

## Layout

```
.github/plugin/marketplace.json   Marketplace catalogue
.github/workflows/ci.yml          Lint and Pester tests
plugins/<plugin>/plugin.json      Plugin manifest
plugins/<plugin>/agents/*.agent.md
plugins/<plugin>/skills/<skill>/SKILL.md
plugins/<plugin>/tests/           Lint, schemas and Pester tests
```