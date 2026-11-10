# Power Platform delivery plugin: rewrite plan

We are rewriting the `power-platform-delivery` plugin from scratch as a Defra-wide agentic Power Platform team. The PIMS export in [`agents-export/`](../agents-export/) is **reference material only**. Use it to decide *what* the agents and skills need to know, but do not port it file by file. Links inside the export don't need to work.

Track progress in [§8](#8-plan-and-progress). Each task has an ID (for example `R2.3`) so issues, pull requests and commits can refer to it. Mark a task `[~]` with an owner when it starts, and `[x]` with a pull request link when it's done.

---

## 1. Principles

1. **Opinionated defaults, project-supplied facts.** The plugin decides *how* work is done: the stack, patterns and gates. The project supplies *where* things are and *what they're called*.
2. **Concise and maintainable.** Every fact lives in exactly one place:
   - Agents describe a role and route to skills; they don't restate skill content.
   - Skills hold procedures; detail lives in `references/` and is loaded only when needed.
3. **Follow plugin and [Agent Skills](https://agentskills.io/specification) conventions.** Skills are portable, can be invoked by any agent or directly by a user, and run without any particular editor or agent tool.
4. **Discover first, then confirm, then configure.** Agents work out project facts from the repo (`*.cdsproj`, `Solution.xml`, `*.csproj`, the git remote). They ask the user only for facts the repo can't give, and store only those in config.
5. **No project history.** Nothing specific to PIMS or any other project ships in the plugin: names, prefixes, domain examples or legacy migrations.

### 1.1 Authoring rules (apply to every file)

| Rule                              | Limit or convention                                                                                                                                                                                                           |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent file length                 | ≤ 100 lines of body                                                                                                                                                                                                           |
| `SKILL.md` length                 | ≤ 150 lines of body. Move detail to `references/*.md`, one level deep                                                                                                                                                         |
| `description` (agents and skills) | Third person; says *what* and *when*; ≤ 400 characters; no repo paths or project names                                                                                                                                        |
| Skill `name`                      | kebab-case, matching the folder name                                                                                                                                                                                          |
| Agent frontmatter                 | `name`, `description` and, only when restricting, `tools` using the portable aliases (`read`, `edit`, `search`, `execute`, `web`, `agent`, `todo`). No `handoffs`. No `model`, except the documented subagent exception (D11) |
| Handoffs                          | Written in prose ("hand off to `solution-architect` when…"), naming agents by id                                                                                                                                              |
| Ownership                         | Use soft "Intended for" wording. Never hard-gate a skill to one agent                                                                                                                                                         |
| Links                             | Only relative links inside the plugin. Never link to a consumer repo path                                                                                                                                                     |
| Scripts                           | PowerShell 7 that works cross-platform. All inputs are parameters with no project defaults. Each script has `-?` help and Pester tests                                                                                        |
| Examples                          | Use one neutral sample domain throughout (proposed: *Case / Applicant / Inspection*, prefix `abc_`)                                                                                                                           |
| Language                          | British English                                                                                                                                                                                                               |

---

## 2. Decisions made

| #   | Decision                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | `agents-export/` is reference only. Its links don't need to work. Its content (including `AGENTS.md`, `CONTRIBUTING.md`, the instructions files and the testing docs) informs the plugin but is not shipped as is.                                                                                                                                                                                                                                                                                                                                                                              |
| D2  | The current `plugins/power-platform-delivery/*` files, including `delivery-lead` and the `solution-checklist` reference, are stubs. They will be replaced.                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| D3  | **Low-code build stays with the human developer.** Agents state what to change in the development environment, in this order: tables, columns, processes, flows, business rules, and plug-in and web resource registrations. The Developer agent only hand-edits the customisation XML that Microsoft supports editing: ribbon, site map, forms and dashboards (FormXml), and views (saved queries).                                                                                                                                                                                            |
| D4  | **No legacy requirements corpus or requirements documents.** Drop all of it: `docs/requirements`, the Jira/`IMTA-` extraction and the conformance matrix. Don't replace it with a config option.                                                                                                                                                                                                                                                                                                                                                                                                |
| D5  | **Agents don't run or edit pipelines.** Remove references to project pipeline files (the PIMS `pipelines/*.yml` paths and template paths). Agents still need to understand the ALM approach that the pipelines implement; see D17.                                                                                                                                                                                                                                                                                                                                                              |
| D6  | **Model generation** uses `pac modelbuilder build --environment <environment-url> -stf <builder-settings-path> --outdirectory ./`. Run it in the folder that contains the model, after confirming the environment URL and settings path with the user. There is no editor task.                                                                                                                                                                                                                                                                                                                 |
| D7  | **Solution versioning** uses [PowerVersion.MSBuild](https://github.com/ewingjm/power-version) in each `.cdsproj`. Commit titles follow Conventional Commits: `feat` is minor, `!` is major, anything else is patch. A commit that changes only mapped files, such as plug-ins or web resources, must have `+semver(<solution-unique-name>): <major                                                                                                                                                                                                                                              | minor | patch>` in the body. ⚠️ The export's `AGENTS.md` says `+solutionVer(...)`, but PowerVersion's source and tests read `+semver(...)`. Use `+semver`. |
| D8  | **`AB#<id>` work item links apply to GitHub-hosted repos only.** Put them in the pull request title and body. Defra is moving repos from Azure Repos to GitHub. Work items stay in Azure Boards.                                                                                                                                                                                                                                                                                                                                                                                                |
| D9  | **No `delivery-lead` orchestrator in v1.** Agents hand off to each other in prose. Revisit once the roles are stable.                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| D10 | **v1 supports VS Code, Copilot CLI and the Copilot coding agent.** The authoring rules in §1.1 keep files neutral across all three.                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| D11 | **Keep `developer-worker` and give it a cheaper model.** See [§5](#5-cheaper-models-for-subagents).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| D12 | **Ship minimal shared code, as skill `assets/`.** Only the `RecordFaker` base (`scenario-builder`) and C# polyfills (`dataverse-plugins`). Move them to Defra NuGet and npm packages once more than one team uses them. See [§4](#4-code-standards-and-shared-code).                                                                                                                                                                                                                                                                                                                                                                       |
| D13 | **The test framework is a preference, not a requirement.** The default is MSTest with FluentAssertions pinned below v8, because v8 needs a commercial licence. If a project already uses a different framework, skills follow the project instead of migrating it.                                                                                                                                                                                                                                                                                                                              |
| D14 | **The stack is recorded once** in `power-platform-standards/references/stack.md`. Plug-ins and custom workflow activities target **.NET Framework 4.8** with **C# 13** (`<LangVersion>13.0</LangVersion>`). Language features that need runtime support, such as default interface members, aren't available. Some features need small polyfills, such as `IsExternalInit` for `init` and records; ship these in the `dataverse-plugins` assets. **spkl is not used at all**: plug-in steps are registered in the development environment by the human (D3) and synchronised with the solution. |
| D15 | **Neutral sample domain** for every example: *Case / Applicant / Inspection*, prefix `abc_`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| D16 | **Azure Boards is the only work tracker.**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| D17 | **ALM follows [power-pipelines](https://github.com/ewingjm/power-pipelines)**, the common Azure Pipelines library that PIMS also uses. It is the basis of our standards, and it lets us shift almost all QA left onto ephemeral environments. Agents design and work *within* this lifecycle; they don't run it (D5). Its preferred approach is described once in `power-platform-design/references/alm.md` and summarised in `power-platform-standards`. See [§3.6](#36-alm-approach).                                                                                                         |
| D18 | **Plug-ins and CWAs follow the export's standards, using the project's own conventions.** Use the project's `Plugin`, `WorkflowActivity` and logging classes; don't ship them. Classes are thin; business logic has no host dependency; code is SOLID and DRY; dependencies are injected without requiring a container; logging is always present. Parse complex step configuration with `DataContractJsonSerializer`. `FieldMappingConfigParser`, `GenericEntityMapper` and the configuration-parameter repository are not carried over. |
| D19 | **No Xrm mock helper for web resource tests.** Set up mocks explicitly for the `formContext` and `Xrm` client API calls the code makes. |
| D20 | **The TypeScript toolchain ships as `web-resources/assets/`** (TypeScript, rollup IIFE bundles, Jest with ts-jest, ESLint flat config, Prettier, and an MSBuild `.proj` wrapper so the solution build runs `npm run build`). It is adapted from `agents-export/typescript/` as described in [§4.1](#41-typescript-toolchain). |
| D21 | **No `@creedengo` ESLint plug-in** in the default toolchain. |
| D22 | **Bundle namespaces derive from the file name**: `contact.ribbon.ts` → `Contact.Ribbon`. No hard-coded map or config file. |
| D23 | **There is no owning team yet.** The plugin author and marketplace owner are `Defra`, with the repository URL and no contact email. Revisit when a team takes ownership (this also fills in CODEOWNERS). The version stays `0.1.0` until v1.0 (R5.3). |
| D24 | **The "do not carry over" list ([§3.5](#35-do-not-carry-over)) is applied in review, not by CI.** Authors and reviewers check changes against it by hand. CI doesn't scan for banned tokens. |

---

## 3. Target plugin design

### 3.1 Layout

```
plugins/power-platform-delivery/
  plugin.json
  agents/<agent-id>.agent.md
  skills/<skill-name>/
    SKILL.md
    references/*.md        # loaded on demand
    assets/*               # templates copied into consumer repos
    scripts/*.ps1          # parameterised, Pester-tested
  tests/                   # Pester tests and lint config for this plugin
```

### 3.2 Agents

| Agent id             | Role                                                                                                                | Main skills                                                                                                                                               | Source in export                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `product-analyst`    | Discovery, user stories, acceptance criteria, Azure Boards, BDD scenarios                                           | `requirements-and-backlog`, `azure-boards`, `bdd-scenarios`                                                                                               | `product-analyst` without the legacy corpus section               |
| `solution-architect` | Review level, options, design, ADRs, risk and fitness                                                               | `architecture-review`, `power-platform-design`, `adr`                                                                                                     | `solution-architect`                                              |
| `developer`          | Pro-code design and implementation, customisation XML, packaging, versioning. Hands low-code work to the human (D3) | `dataverse-plugins`, `web-resources`, `customisation-xml`, `dataverse-schema`, `package-deployer`, `dotnet-build-verification`, `commit-and-pull-request` | `developer` without pipelines, paths or the "Generate model" task |
| `developer-worker`   | Carries out the Developer's approved, tightly scoped briefs on a cheaper model (D11). Not user-invocable            | (as Developer)                                                                                                                                            | `developer-worker`                                                |
| `quality-engineer`   | Test strategy, acceptance and integration tests, test data, review, triage                                          | `acceptance-testing`, `integration-testing`, `scenario-builder`, `test-quality-review`, `test-impact-analysis`, `test-failure-triage`                     | `quality-engineer`                                                |

Every agent loads `power-platform-standards` (§3.3) as the shared house rules instead of repeating them.

### 3.3 Skills (22 in the export → 18)

| Skill                                                                | Intended for | Covers                                                                                                                                                                                                                                                                                                                                                | Built from (reference)                                                                                                                        |
| -------------------------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `power-platform-standards`                                           | All          | Precedence order (user, then ADRs, design, standards, code), low-code first, future-proof solutions (no org-scoped processes or plug-ins on out-of-the-box messages; don't customise managed forms or views), ephemeral environments and a short summary of the ALM approach (D17), zero manual deployment steps, Definition of Done, British English | `AGENTS.md` (general sections and Repository-Specific Standards)                                                                              |
| `requirements-and-backlog`                                           | PA           | Discovery questions, epic/feature/story breakdown, INVEST, acceptance criteria                                                                                                                                                                                                                                                                        | `requirements-discovery`, `backlog-generation`                                                                                                |
| `azure-boards`                                                       | PA, SA       | Create, update and link work items through `az boards`; safe retry rules; comment formatting                                                                                                                                                                                                                                                          | `azure-boards-management` (keep the config, schema and example pattern)                                                                       |
| `bdd-scenarios`                                                      | PA, QE       | Whether a scenario is worth automating, Gherkin style, reusing existing steps, persona login contract                                                                                                                                                                                                                                                 | `bdd-scenario-generation` with its scripts parameterised                                                                                      |
| `architecture-review`                                                | SA           | Review level and complexity, options analysis, decision confidence, risk and technical debt, fitness against ADRs and deprecated components                                                                                                                                                                                                           | `architecture-review-classification`, `architecture-options-analysis`, `risk-and-debt-analysis`, `architecture-fitness-assessment`            |
| `power-platform-design`                                              | SA           | Component selection, data model, security model, configuration over code, the deprecation log template. Includes ALM design: solution boundaries and layering, package composition, environment-specific import configuration, and designing changes for automated deployment to ephemeral environments (`references/alm.md`, D17)                    | `power-platform-architecture-design` (including its ALM section, made generic), [power-pipelines](https://github.com/ewingjm/power-pipelines) |
| `adr`                                                                | SA           | Create, supersede and index ADRs; template in `assets/`                                                                                                                                                                                                                                                                                               | `adr-management`, `architecture/adr/0000-template.md`                                                                                         |
| `dataverse-plugins`                                                  | Dev          | Plug-ins and custom workflow activities (D18): thin classes, host-independent business logic, SOLID and DRY, constructor injection, logging, `DataContractJsonSerializer` step configuration, unit tests (testing a second configuration too)                                                                                                                                                                         | `plugin-authoring`, `cwa-authoring`, `csharp-source` and `unit-tests` instructions                                                            |
| `web-resources`                                                      | Dev          | TypeScript web resources: namespaces, bundling, form and ribbon handlers, Jest with explicit `formContext` and `Xrm` mocks (D19), bundle contract test                                                                                                                                                                                                                                 | `web-resource-script-authoring`, `typescript-*` instructions                                                                                  |
| `customisation-xml`                                                  | Dev          | Hand-edit ribbon, site map, FormXml and saved queries (D3); what must be done in the environment instead                                                                                                                                                                                                                                              | `developer` agent (customisation section)                                                                                                     |
| `dataverse-schema`                                                   | Dev, QE      | Look up table and column metadata and CLR types; regenerate the early-bound model with `pac modelbuilder` (D6)                                                                                                                                                                                                                                        | `scenario-builder-implementation/scripts/Get-Dataverse*.ps1`, `developer` agent                                                               |
| `package-deployer`                                                   | Dev          | Package project structure, core vs seed data, ImportConfig parity, package extension hooks, no manual steps                                                                                                                                                                                                                                           | `developer` agent, `power-platform-architecture-design`                                                                                       |
| `dotnet-build-verification`                                          | Dev          | Build, test and the warning-baseline gate                                                                                                                                                                                                                                                                                                             | `dotnet-build-verification` with the project list discovered or passed in                                                                     |
| `commit-and-pull-request`                                            | Dev, QE      | Conventional Commits, PowerVersion `+semver` (D7), `AB#` on GitHub (D8), pull request description                                                                                                                                                                                                                                                     | `AGENTS.md` (Versioning, Release Management)                                                                                                  |
| `acceptance-testing`                                                 | QE           | Reqnroll, Power Playwright, step design, anti-patterns, recipes                                                                                                                                                                                                                                                                                       | `acceptance-test-automation`, `docs/testing/acceptance/*`                                                                                     |
| `integration-testing`                                                | QE           | Integration test pattern against Dataverse and external boundaries                                                                                                                                                                                                                                                                                    | `integration-test-automation`, `integration-testing-standard.md` without the Marktek content                                                  |
| `scenario-builder`                                                   | QE, Dev      | ScenarioBuilder events and scenarios, Bogus fakers, logging                                                                                                                                                                                                                                                                                           | `scenario-builder-implementation`, `scenario-builder-reference.md`, `common-testing-conventions.md`, `CONTRIBUTING.md` (scenario section)     |
| `test-quality-review`, `test-impact-analysis`, `test-failure-triage` | All          | Review, choosing which tests to run, failure classification and routing                                                                                                                                                                                                                                                                               | Matching export skills. The base branch is discovered, and environment failures route to the human                                            |

### 3.4 Project facts

Agents discover what they can and ask only for the rest. Facts the repo can't give are stored in one small, schema-checked file, `.agent-config/power-platform.json`, which replaces `azure-devops.json`:

| Fact                                                                           | Source                                                                           |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| Solutions, unique names, publisher prefix                                      | Discover from `*.cdsproj` and `Solution.xml`                                     |
| Plug-in, workflow, test and package projects                                   | Discover from `*.csproj` and `*.sln`, then confirm                               |
| Web resource root, JS namespace                                                | Discover from `package.json` and the existing code, then confirm                 |
| Base branch                                                                    | Discover from git (`origin/HEAD`)                                                |
| Repo host (whether `AB#` applies)                                              | Discover from the git remote                                                     |
| Azure Boards organisation, project, area path, work item types                 | **Config**                                                                       |
| Model-driven app name(s) and persona file for acceptance and integration tests | Discovered from `AppModule.xml` files and `Persona.cs` enum in `tests/*` source. |
| `pac modelbuilder` environment URL and settings path                           | Ask each time (D6); don't store it                                               |

### 3.5 Do not carry over

These must not appear in the plugin. Authors and reviewers check for them by hand (D24); CI doesn't.
- PIMS names and identifiers: `Defra.Imports`, `defraimp_`, `defraexp_`, `defra_Imports`, `DefraImports`, `EU Imports`, `TradeImportsPims`, `PIMS`, `IMTA-`.
- PIMS domain examples: Itahc, ImportRecord, animal or commodity examples.
- Marktek and other legacy-migration rules, the CS0507 pitfall, and the struck-out TestCommon text.
- Project pipeline file paths (D5), the requirements corpus (D4) and the "Generate model" task (D6).
- `+solutionVer` (D7), spkl (D14), VS Code-only tool IDs, `handoffs`, and model pins other than D11.
- `FieldMappingConfigParser`, `GenericEntityMapper`, the configuration-parameter repository and the Xrm mock helper (D18, D19).
- `../../../` links and `.github/skills/...` script paths.

### 3.6 ALM approach

`power-platform-design/references/alm.md` describes the lifecycle that [power-pipelines](https://github.com/ewingjm/power-pipelines) implements. It covers only what affects how agents design, build and test; it doesn't document pipeline parameters. `power-platform-standards` summarises it in a few lines, and other skills link to it rather than repeating it.

| Stage                     | What happens                                                                                                                                                                                                             | What it means for agents                                                                                                                                                                                                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Work item dev environment | An ephemeral environment is created for each work item. It is linked to the work item and, optionally, to a branch. The package is deployed with the solution being worked on unmanaged and every other solution managed | Low-code changes (D3) are made here by the human. Agents never assume a shared dev environment                                                                                                                                                                                          |
| Sync solution metadata    | The solution is unpacked from the dev environment and committed to the branch. Missing dependencies are split into separate files to reduce merge conflicts                                                              | Solution metadata is synced, never hand-written, apart from the customisation XML in D3. Pro-code changes are mapped in at build time                                                                                                                                                   |
| Pull request validation   | The package is built, Solution Checker runs, an ephemeral test environment is created, the package is deployed, and automated tests run (`testJobs`). Each stage runs only when the related files changed                | This is where QA shifts left. Acceptance and integration tests must run unattended against a freshly deployed environment, with all their data built by ScenarioBuilder. `test-impact-analysis` should follow the same change categories (solution, package, web resources, assemblies) |
| Build and deploy          | A managed Package Deployer package is built and deployed to static environments, with an optional import configuration per environment                                                                                   | Every change must be deployable by the package alone (zero manual steps). Environment differences go in import configuration, not code                                                                                                                                                  |
| Versioning                | GitVersion versions the package; PowerVersion versions each solution (D7)                                                                                                                                                | Commit messages drive both, which is why `commit-and-pull-request` matters                                                                                                                                                                                                              |
| Clean-up                  | Work item environments are deleted when the work item is completed                                                                                                                                                       | Nothing of value may live only in an environment; it must be in Git or in the package's data                                                                                                                                                                                            |

Agents may recommend power-pipelines features a project isn't using yet, but changing a project's pipelines is for the human (D5).

---

## 4. Code standards and shared code

The export assumes PIMS-only code. The rewrite keeps the standards but ships very little code (D12, D18, D19).

| Export dependency | In the rewrite |
|---|---|
| `Plugin`, `WorkflowActivity` and logging base classes (`ILogWriter`, `GetRequired`) | **Follow the project's existing classes.** Skills describe what a base class and logger must provide, not their names. If a project has none, the skill proposes a minimal one for the human to approve |
| `FieldMappingConfigParser`, `GenericEntityMapper`, configuration-parameter repository | **Removed.** Complex step configuration is parsed with `DataContractJsonSerializer` into a `[DataContract]` class |
| `RecordFaker` | **Ship as an asset** in `scenario-builder` (below) |
| Xrm mock helper | **Removed.** Tests set up mocks explicitly for the `formContext` and `Xrm` client API calls the code under test makes |
| Bundle contract test | Kept as `web-resources` guidance (each bundle exposes its namespace) |
| C# polyfills (`IsExternalInit`) | Ship as an asset in `dataverse-plugins` (D14) |

### 4.1 TypeScript toolchain

`agents-export/typescript/` is a working toolchain with some PIMS coupling and some stale parts. Adapt it as follows:

| File | Keep | Change |
|---|---|---|
| `rollup.config.mjs` | One IIFE bundle per `out/src/*.js`, `context: 'window'`, `extend: true`, source maps | **Remove the hard-coded filename-to-namespace map** (PIMS names). Derive the namespace from the file name only (D22): `contact.ribbon.ts` → `Contact.Ribbon`, each dot-separated segment PascalCased, with no config override. Add `glob` to `devDependencies`, since the config imports it |
| `tsconfig.json` | Strict, ES2022, `rootDir: src`, `outDir: out/src` | Remove the `ts-auto-mock` transformer: it isn't a dependency and conflicts with D19. Move `types` inside `compilerOptions`, where it is currently ignored |
| `tsconfig.jest.json`, `jest.config.cjs` | ts-jest, JUnit output, coverage | Keep. Drop the stale comments |
| `eslint.config.js` | Flat config, type-aware rules, `unbound-method`, Jest override | Drop the unused `eslint:recommended` compat layer if possible. **Remove the `@creedengo` plug-in and its dependency** (D21) |
| `package.json` | Scripts (`lint`, `build`, `test`, `format`) | Prettier is v2 and `@types/node` is 18: bump or justify in `stack.md`. Pin versions in one place (D14) |
| `.prettierrc.js` | 100 columns, single quotes, ES5 trailing commas | Keep as the Defra default |
| `tslint.json`, `.prettierignore` (if unused) | — | **Delete `tslint.json`**: TSLint is deprecated and ESLint is already configured |
| `Defra.Imports.WebResources.proj` | The `Restore` and `Build` targets calling npm | Rename to a neutral name; keep the Windows `npm.cmd` fallback |
| `src/global-types.ts` | `import 'xrm'` | Keep |

**Plug-in and CWA standards** (`dataverse-plugins`, from the export's `plugin-authoring`, `cwa-authoring` and `csharp-source` instructions):
- Plug-in and CWA classes are thin. They read the execution context (target, images, inputs and step configuration), call business logic, and apply the result.
- Business logic lives in separate classes with **no dependency on the host**: no `IPluginExecutionContext`, `CodeActivityContext` or other plug-in or CWA types. The same logic can be called from any plug-in, CWA or other host.
- Code is SOLID and DRY. Dependencies are injected through constructors. **A DI container is not required**; composing dependencies by hand in the plug-in or CWA class is fine.
- Observability and logging are always present: tracing through the project's logging abstraction, with enough context to diagnose failures from plug-in trace logs.
- Configurable, generic and granular, with tests that cover a second configuration (kept from the export).

`RecordFaker` asset (the full implementation):

```csharp
using Bogus;
using Microsoft.Xrm.Sdk;

/// <summary>
/// A base <see cref="Faker{T}"/> for Dataverse early-bound entities, applying the conventions shared by every
/// record faker: an <c>en_GB</c> locale and a randomly generated <see cref="Entity.Id"/>.
/// </summary>
/// <typeparam name="TEntity">The Dataverse early-bound entity type.</typeparam>
public abstract class RecordFaker<TEntity> : Faker<TEntity>
    where TEntity : Entity, new()
{
    /// <summary>
    /// Initializes a new instance of the <see cref="RecordFaker{TEntity}"/> class.
    /// </summary>
    protected RecordFaker()
    {
        this.Locale = "en_GB";

        this.RuleFor(e => e.Id, f => f.Random.Guid());
    }
}
```

---

## 5. Cheaper models for subagents

`model` is a supported field in custom agent frontmatter in both VS Code and GitHub Copilot ([custom agents configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration)). An agent with `model` set runs on that model whenever it is invoked, including as a subagent. Without it, the agent inherits the caller's model, so there is no cost saving. Pinning is therefore the only portable way to get a cheaper worker. The rule is a single, controlled exception, not a ban:

- **Only `developer-worker` sets `model`.** Every other agent inherits the user's choice.
- **Pick a small, generally available model**, not a preview one. In VS Code, `model` can also be a priority list, so give a fallback.
- **Set `user-invocable: false`** so the worker is only reached through the Developer's brief.
- **Keep the model name in one place** and have CI check it against an allow-list (R1.3). The allow-list is `allowedModels` in `plugins/power-platform-delivery/tests/lint.config.json`. It starts empty, so R2.8 must add the chosen model. Review it at each release, so the pin doesn't go out of date silently.
- **The Developer escalates rather than retries.** If the worker reports the brief is beyond it, the Developer does the work itself on the user's model.

**To confirm in R5.1:** how each of the three supported tools behaves when the pinned model isn't available to the user (for example, blocked by org policy). If any tool fails rather than falling back, document the workaround (a fallback list, or the Developer doing the work itself) in the agent.

---

## 6. Open questions

Record answers as decisions in §2.

None at present. Add new questions here as `O<n>`.

---

## 7. Gaps to schedule after v1

- Project bootstrap: scaffold `.agent-config/`, `AGENTS.md`, the ADR folder, test projects and the PowerVersion reference.
- Implementing security roles and column security. (power-pipelines already runs Solution Checker when it builds and validates a package; agents only need to act on its results.)
- Telemetry and operability: plug-in tracing and App Insights.
- PCF, Power Pages (with WCAG 2.2 and the GDS Service Standard) and Copilot Studio, as demand dictates.
- An environment owner for `test-failure-triage`. In v1, these failures route to the human, who owns the power-pipelines environments.

---

## 8. Plan and progress

Legend: `[ ]` not started · `[~]` in progress (add owner) · `[x]` done (add PR link)

### R0 — Decide
- [x] **R0.1** Gather the reference artefacts into `agents-export/` and remove the unused mermaid files.
- [x] **R0.2** Record decisions D1–D8 and D17–D19.
- [x] **R0.3** Resolve open decisions O1–O8 (recorded as D9–D16).

### R1 — Foundations
- [x] **R1.1** (`feature/power-platform-delivery-plugin`) Replace the stub `plugin.json`, with the real author and owner, the version, and the `agents` and `skills` paths. Remove the stub agents. (Author and owner: D23.)
- [x] **R1.2** (`feature/power-platform-delivery-plugin`; PR link to follow) Add an authoring guide to this repo covering §1.1, §3.4 and §3.5. Add CODEOWNERS and a CHANGELOG. (Guide: `docs/authoring-guide.md`. CODEOWNERS has no rule until a team owns the plugin, D23. CHANGELOG: `plugins/power-platform-delivery/CHANGELOG.md`.)
- [x] **R1.3** (`feature/power-platform-delivery-plugin`; PR link to follow) Add CI (`.github/workflows/ci.yml`, with the checks in `plugins/power-platform-delivery/tests/`):
  - frontmatter lint (name matches folder, description length);
  - line budgets;
  - an in-plugin link check;
  - JSON schema validation;
  - Pester tests on Windows and Linux;
  - a check that `model` appears only on `developer-worker` and names an allowed model (§5).
- [x] **R1.4** (`feature/power-platform-delivery-plugin`; PR link to follow) Write `power-platform-standards`, including `references/stack.md` (D14).
- [x] **R1.5** (`feature/power-platform-delivery-plugin`; PR link to follow) Define `.agent-config/power-platform.json`: schema, example, and the discover-then-confirm procedure (§3.4). (In `power-platform-standards`: `assets/power-platform.schema.json`, `assets/power-platform.example.json` and `references/project-facts.md`.)

### R2 — Developer
- [ ] **R2.1** `dataverse-plugins` (D18), with C# polyfill assets (D12, D14) and unit-test guidance (D13).
- [ ] **R2.2** `web-resources`, with the toolchain assets (D20, §4.1), explicit mock guidance (D19) and the bundle contract test.
- [ ] **R2.3** `customisation-xml`.
- [ ] **R2.4** `dataverse-schema`: make the lookup scripts parameterised and add `pac modelbuilder` (D6).
- [ ] **R2.5** `package-deployer`.
- [ ] **R2.6** `dotnet-build-verification`, with scripts that discover projects and Pester tests.
- [ ] **R2.7** `commit-and-pull-request` (D7, D8).
- [ ] **R2.8** The `developer` agent, and `developer-worker` with its model exception (D11, §5).

### R3 — Quality Engineer
- [ ] **R3.1** `scenario-builder`, with the `RecordFaker` asset from §4 (D12).
- [ ] **R3.2** `acceptance-testing`.
- [ ] **R3.3** `integration-testing`.
- [ ] **R3.4** `test-quality-review`, `test-impact-analysis` and `test-failure-triage`.
- [ ] **R3.5** The `quality-engineer` agent.

### R4 — Product Analyst and Solution Architect
- [ ] **R4.1** `requirements-and-backlog`.
- [ ] **R4.2** `azure-boards`, moving to the shared config file.
- [ ] **R4.3** `bdd-scenarios`, with the index scripts parameterised.
- [ ] **R4.4** `architecture-review`, `power-platform-design` (including `references/alm.md`, D17) and `adr`.
- [ ] **R4.5** The `product-analyst` and `solution-architect` agents.

### R5 — Prove and release
- [ ] **R5.1** Build a neutral sample Power Platform repo (D15) to evaluate against, with scripted scenarios for each agent: "add a configurable plug-in", "edit a form", "write BDD for story X", "triage a failing test".
- [ ] **R5.2** Pilot with one Defra team outside PIMS and act on their feedback.
- [ ] **R5.3** Update the README, publish v1.0, and remove `agents-export/`.

---

## 9. Keep (worth carrying into the rewrite)

- Proportional architecture: review level and complexity, and decision confidence ratings.
- ADR-first precedence, contract-first change and the deprecation log.
- The Developer's design gate (proceeds only on explicit approval), capability naming, configuration over code, and TDD with a test for a second configuration.
- The Developer → Worker brief format and fixed report.
- The warning-baseline gate, which diffs warnings against a stored baseline.
- The BDD check on whether a scenario is worth automating (each scenario is a deployment-gate cost), and the step and scenario index scripts.
- The acceptance-testing docs. They already use a neutral domain and are close to shippable as `references/`.
- The Azure Boards guidance on unsafe retries and comment formatting, and its config, schema and example pattern.
- Test failure classification and the routing table.
