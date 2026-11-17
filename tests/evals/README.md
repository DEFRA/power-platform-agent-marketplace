# Evals

Evals for the `power-platform-delivery` plugin. They run GitHub Copilot CLI headlessly against the plugin on [promptfoo](https://www.promptfoo.dev/), and cost Copilot credits. They run on a developer's machine only and never in CI. The plan, decisions and findings are in [docs/testing-plan.md](../../docs/testing-plan.md).

Only the routing suite exists so far: does a natural prompt load the intended skill? Behaviour evals come in Phase 3.

## Prerequisites

- Node 20 or later, and `npm ci` in this folder.
- Copilot CLI, installed with `npm install -g @github/copilot`. Developed against 1.0.112.
- A token in `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` or `GITHUB_TOKEN`. Runs use an isolated `COPILOT_HOME`, so a stored `copilot login` isn't used. Never print or commit a token.
- Tested on Windows only. Linux and macOS are untested: the provider starts `copilot` directly there, and the shell and write tool names may differ.

## Run

```powershell
npm run eval:routing                                       # all cases, about 15 minutes
npm run eval:routing -- --filter-pattern "adr"             # one skill
npm run eval:routing -- --max-concurrency 4                # default is 8 parallel runs
npm run eval:routing -- --repeat 3                         # repeat each case for a pass rate
npm run test:unit                                          # provider unit tests, no credentials
```

Results go to `results/` (git-ignored) as JSON and HTML, and the thresholds in `baselines/routing.json` are then checked. Exit code 0 is within thresholds, 1 is below, 2 means some runs ended in a provider error and the run is incomplete.

## Safety

- Each run happens in a temporary copy of the fixture, never in this repository. `--allow-all-paths` is never passed.
- Routing runs deny `shell` and `write`, so they are read-only. Every run has a cap of 30 credits, the minimum Copilot CLI accepts.
- Set `COPILOT_EVAL_KEEP_TEMP=1` to keep a run's working folder for debugging.
- Results are never shared to a hosted service.

## Layout

| Path                                       | Purpose                                                           |
| ------------------------------------------ | ----------------------------------------------------------------- |
| `providers/copilot-cli.js`                 | The promptfoo provider. Config keys are in the plan, §7.1         |
| `providers/transcript.js`                  | Pure parsing of the JSONL transcript and usage file into evidence |
| `providers/recordings/`                    | Scrubbed transcripts that the unit tests use                      |
| `assertions/evidence.js`                   | Shared assertions over the provider's `metadata`                  |
| `cases/routing.yaml`                       | The routing cases                                                 |
| `scripts/eval.js`, `scripts/thresholds.js` | The run command and the threshold check                           |
| `baselines/routing.json`                   | The recorded baseline pass rate                                   |
