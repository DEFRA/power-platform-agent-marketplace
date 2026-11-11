---
name: web-resources
description: Designs, writes and reviews the TypeScript web resource scripts for model-driven app form, ribbon and subgrid handlers, with their Jest tests, and ships the toolchain to build them. Covers capability naming, data-driven handlers, test-first development, explicit Xrm mocks, bundling and namespaces, and the registration hand-off. Use for any request to add or change a form, ribbon or subgrid script.
---

# Web resources (TypeScript)

Intended for `developer` (and `developer-worker` on an approved brief), but usable by anyone. Load `power-platform-standards` first. This skill is the procedure. Rules and code live in `references/`, loaded when a step needs them.

| Reference                               | Load it when                                                       |
| --------------------------------------- | ------------------------------------------------------------------ |
| [standards.md](references/standards.md) | Writing or reviewing a script or its tests                         |
| [example.md](references/example.md)     | You want a worked, tested handler to adapt                         |
| [toolchain.md](references/toolchain.md) | Setting up the toolchain, adding a script, or building and testing |

## Layout

Discover the web resource root (the folder with `package.json` and `rollup.config.mjs`) and confirm it, as in [project-facts.md](../power-platform-standards/references/project-facts.md). Don't assume a path. If the project has no toolchain, propose copying the files in [assets/](assets/), for the human to approve.

| Path                                           | Purpose                                                                                      |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `src/<name>.<form\|ribbon\|subgrid.ribbon>.ts` | One script per web resource. Exported functions are the handlers that forms and ribbons call |
| `tests/<name>.test.ts`                         | Jest tests for that script                                                                   |
| `tests/bundle.contract.test.ts`                | Checks that every script is built and exposes its namespace                                  |
| `out/`, `dist/`, `coverage/`, `test-results/`  | Build and test output. Never edit or commit                                                  |

The file name sets the namespace. `contact.ribbon.ts` is bundled as `dist/contact.ribbon.js` and exposes `Contact.Ribbon`, so the solution calls a handler as `Contact.Ribbon.<function>`. A project that already has another namespace scheme keeps it.

## Principles in one line each

- **Name it for the capability**, not the first use case. The first requirement is one registration.
- **Data-driven.** What varies by form, field, action or threshold arrives as handler parameters (usually a JSON string), parsed and validated in one place. Never constants.
- **Thin handlers over small pure functions.** Decisions need no Xrm mock. Xrm calls stay thin.
- **Declarative first.** Business rules, form configuration, workflows, actions and flows come before script. If the request is really a business process, say so in the design and don't write script until the user decides.
- **Strict types, no suppressions**, and mocks set up explicitly for the calls the code makes (no shared Xrm mock helper).
- **Test first**, including a second, different configuration.

## Procedure

1. **Discover the project** (above), and read the neighbouring script closest to the target and its test.
2. **Generalise first.** Restate the requirement as the capability it is an instance of, and write down the handler name. Look for an existing handler to reuse through registration data. Ask: "If a second form needed this next month, would a handler registration be enough?"
3. **Capture the contract.** Which form, ribbon button or subgrid calls the handler, on which event, with what parameters (`executionContext` or `primaryControl`, plus the registration parameters, which are the configuration), and what must happen on failure. Ask for what is missing.
4. **Propose the design and wait for explicit approval.** State the capability, files, handler names and signatures, the configuration and its format, the ordered test list (simplest first, with a second-configuration test), what the human must register, and how the design meets each principle.
5. **Take baselines.** Run lint, format check and tests first and note any failures, so you can tell what you caused.
6. **Build test-first, one behaviour at a time.** Red, green, refactor. Confirm each test fails for the right reason before writing its code. Follow [standards.md](references/standards.md), and adapt [example.md](references/example.md).
7. **Verify.** Run `npm run format`, then `npm run lint`, `npm run format:check` and `npm test` (see [toolchain.md](references/toolchain.md)). All must pass. Then tick the checklist below.
8. **Report and hand off** (below), including how the design meets the principles.

## Registration hand-off

Registering the web resource is solution metadata, made by the human in their development environment and synchronised. Never hand-edit the solution's web resource components. Wiring a handler into a form or ribbon is a FormXml or ribbon edit that `customisation-xml` allows, once the web resource is in the solution. Otherwise the human wires it too. Tell the human:

- the web resource to create or update, and the built file in `dist/` to upload;
- for each handler, the library, the function (`<Namespace>.<function>`), the event it is bound to, the exact parameters to enter, and whether to tick "Pass execution context as first parameter". Reusing a handler on another form is another registration with its own parameters;
- that renaming, removing or changing the signature of an exported function breaks forms and ribbons that already call it;
- that script changes outside the synced solution metadata need a `+semver(<solution-unique-name>): <major|minor|patch>` line in the commit body (see `commit-and-pull-request`).

## Test checklist

- Each test was written first and seen to fail before its code existed.
- A second, different configuration changes the behaviour with no code change.
- Missing, malformed or incomplete configuration fails with a clear error.
- Each exported handler has a test for its main path and each branch.
- A missing attribute, control or form type is handled as designed.
- Every `Xrm.WebApi`, navigation and utility call is asserted with its arguments, and a rejected call is tested.
- UI side effects are asserted, and a progress indicator is closed on failure as well as success.
- The bundle contract test passes, and no test depends on order or on another test's state.
