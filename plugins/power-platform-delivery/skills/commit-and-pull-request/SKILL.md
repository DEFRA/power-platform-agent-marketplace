---
name: commit-and-pull-request
description: Writes Conventional Commit messages and pull request titles and descriptions that drive automatic solution and package versioning, including the PowerVersion +semver line for changes outside the solution folder and AB# work item links on GitHub-hosted repositories. Use before committing, when preparing a pull request, or when asked what version increment a change will cause.
---

# Commit and pull request

Intended for `developer` and `quality-engineer`, but usable by anyone. Load `power-platform-standards` first.

Commits drive versioning. GitVersion versions the package, and [PowerVersion](https://github.com/ewingjm/power-version) versions each solution from the Git history. A wrong title gives a wrong version, so check it before you commit.

## Commit titles

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`. The title sets the increment:

| Title | Increment | Why |
| --- | --- | --- |
| `feat!: remove the status column` | Major | An exclamation mark follows the type |
| `feat: add inspection outcome` | Minor | The type is `feat` and there is no exclamation mark |
| `fix: correct the due date` | Patch | Any other type |

Use `fix`, `refactor`, `test`, `docs` and `chore` for what they say. Never use `feat` for a change that adds nothing a user could see, and never leave the `!` off a breaking change. Keep the summary short, in the imperative and in British English.

Never commit, push or stage unless the user asks. When asked, follow the rules below.

## Changes outside the solution folder

A solution is versioned when a commit changes files in its own folder, and the title sets the increment. A commit that changes only *mapped* files, such as plug-in assemblies or web resource scripts that are built into the solution, has no change in the solution's folder. PowerVersion can't see it, so the commit body must say which solution to increment:

```text
feat: add the inspection reminder activity

+semver(<solution-unique-name>): minor
```

- The value is `major`, `minor` or `patch`. It should match the increment the title implies.
- Use the solution's unique name. Discover it from `Solution.xml` and the `.cdsproj`, and don't guess.
- Spell it exactly `+semver(<solution-unique-name>): <increment>`, with the plus sign.
- Put it in the body, after a blank line. One line for each solution the change affects.
- A commit that also changes the solution's own files doesn't need it.
- Tests and documentation aren't mapped into a solution. A change to those alone needs no line.

## Pull requests

- **Title.** Write it as a Conventional Commit too, because squash merges use it. It must give the same increment as the commits.
- **Body.** Say what changed and why, how it was verified (the `dotnet-build-verification` or `npm test` result), what the human must do in an environment (register a step, re-export data, synchronise the solution), and any risks or open questions. Keep it short.
- **Work item.** If the repository is hosted on GitHub, put `AB#<id>` in the title and the body, so Azure Boards links the pull request to its work item. Ask for the id if you don't have it. If the repository is on Azure Repos, links are made another way and `AB#` isn't needed. Discover the host from the git remote and don't ask.
- **Base branch.** Discover it from `origin/HEAD`. Don't assume `main`.
- Don't mark work done in Azure Boards from here. That's the `azure-boards` skill, and only when asked.

## Checklist before committing

- The title is a Conventional Commit and has the right type and `!`.
- The body has a `+semver(...)` line if only mapped files changed, with the right unique name.
- Nothing unrelated is staged, and no secrets or generated output are in the diff.
- The gate for the change has passed.
- The pull request title and body carry `AB#<id>` when the repository is on GitHub.
