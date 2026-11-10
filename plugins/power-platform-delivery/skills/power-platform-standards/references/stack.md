# Technology stack

The single place that records the default stack and versions. Other skills link here instead of restating it. A project that already uses something different keeps it: follow the project, don't migrate it.

Versions below are the known-good baseline. The skill that builds each toolchain (for example `web-resources`) re-confirms them when it ships, and updates this file rather than its own text.

## Server-side (.NET)

| Area | Default | Notes |
| --- | --- | --- |
| Plug-ins and custom workflow activities | .NET Framework 4.8 | Dataverse requires it. |
| Language | C# 13 (`<LangVersion>13.0</LangVersion>`) | Features that need runtime support, such as default interface members, aren't available. Small polyfills cover some others, such as `IsExternalInit` for `init` and records (shipped by `dataverse-plugins`). |
| Early-bound model | `pac modelbuilder` | Run by the `dataverse-schema` skill. |
| Step configuration | `DataContractJsonSerializer` into a `[DataContract]` class | Used for any step configuration more complex than a simple value. |
| Plug-in step registration | By the human, in the development environment | spkl and similar tools aren't used. |

## Tests (.NET)

| Area | Default | Notes |
| --- | --- | --- |
| Unit and integration tests | MSTest | A preference. If the project uses another framework, follow it. |
| Assertions | FluentAssertions **below v8** (`[7.0.0, 8.0.0)`) | v8 and later need a commercial licence. |
| Test data | ScenarioBuilder with Bogus (`en_GB` locale) | See the `scenario-builder` skill. |
| Acceptance tests | Reqnroll with Power Playwright | See the `acceptance-testing` skill. |

## Web resources (TypeScript)

| Area | Default |
| --- | --- |
| Language and target | TypeScript 6.0 (`^6.0.3`), strict, ES2022 |
| Bundling | Rollup 4 (`^4.68.0`), one IIFE bundle per source file |
| Unit tests | Jest 30 (`^30.2.0`) with ts-jest 29 (`^29.4.6`) and `@types/jest` 30 (`^30.0.0`) |
| Linting | ESLint 10 flat config (`^10.0.0`, with `@eslint/js` 10), typescript-eslint 8 (`^8.72.2`), `eslint-plugin-jest` 29 (`^29.0.0`) |
| Formatting | Prettier 3 (`^3.9.0`): 100 columns, single quotes, ES5 trailing commas |
| Xrm types | `@types/xrm` (`^9.0.97`) |
| Build integration | An MSBuild `.proj` wrapper that runs `npm run build` |

Notes:

- These versions were tested on a real Power Platform repository: a clean install, lint, build, tests and the bundle output, plus the MSBuild wrapper. Bundle namespaces and compiled JavaScript were identical to the previous baseline.
- **TypeScript 7 doesn't work yet.** `typescript-eslint` supports TypeScript below 6.1 and `ts-jest` supports below 7. Stay on 6.x until both do.
- **TypeScript 6** no longer includes `@types/*` packages automatically. Set `"types": ["node", "xrm"]` inside `compilerOptions`. A top-level `types` property is ignored.
- **ESLint 10** is flat config only. Don't use `@eslint/eslintrc` or `FlatCompat`; extend `js.configs.recommended` and typescript-eslint's `flat/recommended-type-checked` directly.
- Prettier moves from the export's v2 to v3. Set `trailingComma: 'es5'` explicitly, because v3 changed the default to `all`. v3 also wraps constructor parameter properties and adds trailing commas in tuple types, and no option reverts this. Reformat once with `prettier --write` when adopting it.
- **Node.js:** the build needs 22.13 or later on the 22 line, 20.19 or later on the 20 line, or 24 or later. These are the minimums for ESLint 10. `@types/node` matches the major version of the Node.js LTS release the build uses. Don't pin to a release that is out of support.
- Declare `glob` in `devDependencies`. The Rollup config imports it, and without a declaration it only works because another package happens to hoist it.
- There is no `@creedengo` ESLint plug-in and no TSLint.
- Pin versions in `package.json`, committed with its lock file. Update the table here when the baseline moves.

## Tooling

| Area | Default |
| --- | --- |
| Solution versioning | [PowerVersion.MSBuild](https://github.com/ewingjm/power-version) in each `.cdsproj` |
| Package versioning | GitVersion |
| ALM | [power-pipelines](https://github.com/ewingjm/power-pipelines) |
| Work tracking | Azure Boards |
| Scripts shipped by this plugin | PowerShell 7, cross-platform, tested with Pester 5 |
