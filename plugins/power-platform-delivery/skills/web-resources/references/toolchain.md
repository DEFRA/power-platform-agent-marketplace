# Toolchain

The files in [assets/](../assets/) are the default toolchain. Versions are in [stack.md](../../power-platform-standards/references/stack.md), which is where they're updated. A project with its own toolchain keeps it.

## Setting up

Copy the assets into the web resource root the human agrees, and run `npm install` to create the lock file, which is committed. Then add the `WebResources.proj` to the solution's build so a normal build runs `npm run build`. It calls npm (with a Windows `npm.cmd` fallback) and its path is set by the project, not by this skill.

| Asset                                                 | Purpose                                                                                                                                                                                                                                   |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `package.json`, `tsconfig.json`, `tsconfig.jest.json` | Scripts and strict TypeScript (ES2022). `src` compiles to `out/src`                                                                                                                                                                       |
| `rollup.config.mjs`, `namespace.cjs`                  | One IIFE bundle per `out/src/*.js`, written to `dist/`. The namespace comes from the file name only: `contact.ribbon.ts` becomes `Contact.Ribbon`, each dot-separated segment PascalCased. No map or config. `global-types.ts` is skipped |
| `jest.config.cjs`                                     | ts-jest, JUnit output in `test-results/` and coverage                                                                                                                                                                                     |
| `eslint.config.mjs`                                   | Flat config, type-aware, with `unbound-method`                                                                                                                                                                                            |
| `.prettierrc.js`, `.prettierignore`                   | 100 columns, single quotes, ES5 trailing commas                                                                                                                                                                                           |
| `src/global-types.ts`                                 | Imports the Xrm typings                                                                                                                                                                                                                   |
| `tests/bundle.contract.test.ts`                       | Checks every script is built and exposes its namespace                                                                                                                                                                                    |
| `WebResources.proj`                                   | MSBuild wrapper that restores and builds with npm                                                                                                                                                                                         |

## Commands

Run from the web resource root.

| Command                                          | Use                                                                                                           |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `npm run lint`                                   | ESLint over the source and tests. Must stay clean                                                             |
| `npm run format` / `npm run format:check`        | Format, and check formatting. The check must pass                                                             |
| `npm test`                                       | Builds (`tsc`, then rollup), then runs Jest with coverage and the bundle contract test. This is the full gate |
| `npx jest tests/<name>.test.ts --coverage=false` | One file while iterating. It doesn't build, so finish with `npm test`                                         |

## Adding a script

Add `src/<name>.<kind>.ts` and its test. Nothing else needs registering: the build discovers the file and derives its namespace. Tell the human the namespace and built file so they can register it (see the hand-off in `SKILL.md`).
