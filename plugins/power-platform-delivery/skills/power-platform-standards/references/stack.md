# Technology stack

The single place that records the default stack and versions. Other skills link here instead of restating it. A project that already uses something different keeps it: follow the project, don't migrate it.

Versions below are the known-good baseline. The skill that builds each toolchain (for example `web-resources`) re-confirms them when it ships, and updates this file rather than its own text.

## Server-side (.NET)

| Area                                    | Default                                                                                                                | Notes                                                                                                                                                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plug-ins and custom workflow activities | .NET Framework 4.8                                                                                                     | Dataverse requires it.                                                                                                                                                                                        |
| Language                                | C# 13 (`<LangVersion>13.0</LangVersion>`)                                                                              | Features that need runtime support, such as default interface members, aren't available. Small polyfills cover some others, such as `IsExternalInit` for `init` and records (shipped by `dataverse-plugins`). |
| Early-bound model                       | `pac modelbuilder`                                                                                                     | Run by the `dataverse-schema` skill.                                                                                                                                                                          |
| Step configuration                      | `DataContractJsonSerializer` into a `[DataContract]` class                                                             | Used for any step configuration more complex than a simple value.                                                                                                                                             |
| Shared code                             | Shared projects for the infrastructure, the Dataverse layer (model, contexts and queries) and the application services | Plug-in packages don't support custom workflow activities. Unit tests build in a `UnitTest` configuration against a single shared-code assembly. See `dataverse-plugins`.                                     |
| Plug-in and workflow structure          | Handler-first, with dependency injection                                                                               | Each plug-in or activity resolves a handler from a composition root, through a small container that compiles into each assembly. Shipped as code assets for reference by `dataverse-plugins`.                       |
| Plug-in step registration               | By the human, in the development environment                                                                           | spkl and similar tools aren't used.                                                                                                                                                                           |

## Tests (.NET)

| Area                       | Default                                          | Notes                                                                                                                   |
| -------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Unit and integration tests | MSTest                                           | A preference. If the project uses another framework, follow it.                                                         |
| Assertions                 | FluentAssertions **below v8** (`[7.0.0, 8.0.0)`) | v8 and later need a commercial licence.                                                                                 |
| Mocking                    | Moq (4.20.2 or later)                            | A preference. If the project uses another library, follow it. Avoid 4.20.0 and 4.20.1, which shipped SponsorLink. |
| Test project target        | `net48`                                          | Matches the code under test, which references the same Dataverse SDK assemblies.                                        |
| Test data                  | ScenarioBuilder with Bogus (`en_GB` locale)      | See the `scenario-builder` skill.                                                                                       |
| Acceptance tests           | Reqnroll with Power Playwright                   | See the `acceptance-testing` skill.                                                                                     |

## Web resources (TypeScript)

| Area                | Default                                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Language and target | TypeScript 6.0 (`^6.0.3`), strict, ES2022                                                                                     |
| Bundling            | Rollup 4 (`^4.68.0`), one IIFE bundle per source file                                                                         |
| Unit tests          | Jest 30 (`^30.2.0`) with ts-jest 29 (`^29.4.6`) and `@types/jest` 30 (`^30.0.0`)                                              |
| Linting             | ESLint 10 flat config (`^10.0.0`, with `@eslint/js` 10), typescript-eslint 8 (`^8.72.2`), `eslint-plugin-jest` 29 (`^29.0.0`) |
| Formatting          | Prettier 3 (`^3.9.0`): 100 columns, single quotes, ES5 trailing commas                                                        |
| Xrm types           | `@types/xrm` (`^9.0.97`)                                                                                                      |
| Build integration   | An MSBuild `.proj` wrapper that runs `npm run build`                                                                          |

Notes:

- This is a known-good baseline: the versions were tested together (clean install, lint, build and tests) on a real Power Platform repository. A project that already uses other versions keeps them.
- TypeScript 7 isn't supported by the rest of the toolchain yet: `typescript-eslint` supports TypeScript below 6.1 and `ts-jest` below 7.
- The build needs Node.js 22.13 or later on the 22 line, 20.19 or later on the 20 line, or 24 or later (the minimums for ESLint 10). `@types/node` matches the major version of the Node.js LTS release the build uses.
- The `web-resources` assets pin these versions, plus `glob` 11, `jest-junit` 17, `globals` 17 and `@types/node` 24. A clean install, lint, build and test run passes on Node 26.
- There is no `@creedengo` ESLint plug-in and no TSLint.
- Pin versions in `package.json`, committed with its lock file. Update the table here when the baseline moves.

## Tooling

| Area                           | Default                                                                             |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| Solution versioning            | [PowerVersion.MSBuild](https://github.com/ewingjm/power-version) in each `.cdsproj` |
| Package versioning             | GitVersion                                                                          |
| ALM                            | [power-pipelines](https://github.com/ewingjm/power-pipelines)                       |
| Work tracking                  | Azure Boards                                                                        |
| Scripts shipped by this plugin | PowerShell 7, cross-platform, tested with Pester 5                                  |
