# Web resource standards

Rules for the scripts and their tests. Follow the neighbouring scripts where these are silent.

## Scope

- Make the smallest change that delivers the request. Don't refactor unrelated scripts.
- An existing handler's behaviour is frozen unless a change is approved. Forms and ribbons call it by name, so don't rename or remove an exported function, change its parameters or change what it does for existing callers. Flag a suspected bug in your report instead of fixing it.
- Add no dependencies, and don't change `package.json` or the lock file, unless the user asks. Builds install from the lock file.

## Design

- **Single responsibility.** A handler reads its inputs, calls small functions that parse, decide and apply, and nothing more. Decision logic is pure.
- **Open/closed.** Add behaviour by adding data, a registration or a small function, not a branch in a working handler. Replace `if` chains on a name or key with a lookup that data chooses.
- **Depend on the narrowest thing**: a value, a control or an attribute, not the whole form context. Where a function needs a service such as `Xrm.WebApi`, take it as a parameter or reach it through one thin function, so a test can substitute it.
- **Data-driven.** Anything that varies by form, field, control, action, key or threshold is data. Parse and validate it in one place, fail with a clear error on bad data, and cover it with tests. Hard-code only what is structural.
- **Capability naming.** Name files, namespaces, handlers and types for the capability: `applyVisibilityRules`, not `hideSectionWhenStatusClosed`. A table name belongs in a file name only when the script is about that table.
- **No speculative generality.** Generalise to what the requirement plainly implies and no further.

## Typing and Xrm

- Use the ambient types from `@types/xrm` (`Xrm.FormContext`, `Xrm.Events.EventContext`, `Xrm.Attributes.*`, `Xrm.Controls.*`). Don't import them.
- No `any`, non-null assertions (`!`) or blanket type assertions. Narrow `unknown` with a type guard, as in [example.md](example.md). Type every exported function's parameters and return value (`Promise<void>` for async handlers).
- Don't use `Xrm.Page`. Get the form context from `executionContext.getFormContext()` or the ribbon's `primaryControl`.
- Resolve attributes, controls, tabs and sections by logical name and fail with a clear error when a required one is missing.
- A handler that takes `executionContext` is registered with "Pass execution context as first parameter".
- Use `Xrm.WebApi` for data. Select only the columns you need and never build a query from unvalidated input.
- Use `async` and `await`. Never leave a promise unhandled: catch the rejection and surface it with `Xrm.Navigation.openErrorDialog` or `openAlertDialog`.
- Close any progress indicator in a `finally` block.
- Don't hard-code environment URLs, tenant data, secrets or personal data. A record GUID is environment-specific unless the solution ships the record: read it from a configuration record or a handler parameter.
- Make a handler safe to run twice (a double click, a repeated `OnSave`), or disable the control while it runs.
- Avoid module-level state. Where it's unavoidable, comment why, and reset it between tests with `jest.resetModules()` and a fresh `require`.

## Style

- Prettier and ESLint are configured by the toolchain. Don't hand-format. Don't add suppressions (`eslint-disable`, `@ts-ignore`, `@ts-expect-error`) or weaken `tsconfig.json` or the ESLint config without approval for that specific suppression.
- Comment only what needs clarifying. Error messages are read by makers, so make them specific. Write in British English.

## Tests

- Jest with ts-jest, in a Node environment. Xrm isn't available, so each test builds its own mocks.
- **Test-driven.** Red (the first red for a new script is a missing module), green, refactor. Test through the exported handler. A bug fix starts with a test that reproduces it.
- Order the first tests from simplest to most general. Every data-driven handler has a second-configuration test and a `test.each` for invalid configuration (empty, malformed, incomplete).
- **Explicit mocks, no shared Xrm mock helper.** Build plain objects for only the `formContext`, attributes, controls and `Xrm` client API calls the code under test makes, and cast them (`as unknown as Xrm.FormContext`) at the call. Keep small builder functions at the top of the test file. If two files need the same builder, move it to a test file of its own, and keep it minimal. Install a global `Xrm` only for scripts that reach `Xrm.WebApi`, `Xrm.Navigation` or `Xrm.Utility`, set it in `beforeEach`, and set results with `mockResolvedValue` and `mockRejectedValue`.
- Assert every `Xrm.WebApi`, navigation and utility call with its arguments, the calls that must not happen, UI effects, and the progress indicator closing on failure.
- For async handlers, `await` the call and test the rejected path.
- No real timers, network or file system, apart from the bundle contract test, which reads `dist/`.
- One test file per script: `tests/<name>.test.ts`. Group with `describe` named for the handler, and name each test as a sentence stating the behaviour. Arrange, act, assert.
- Don't copy production GUIDs into tests.

## The bundle contract test

`tests/bundle.contract.test.ts` loads each built bundle in a fresh context and checks that it exposes functions on the namespace derived from its file name. It needs a build, which `npm test` runs first. It catches a script that isn't bundled or whose namespace has drifted. A project that needs to pin specific handler names can add a list to it. Don't edit it to make a failing test pass without confirming the solution no longer calls the handler.
