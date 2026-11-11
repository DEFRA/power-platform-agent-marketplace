---
name: dotnet-build-verification
description: Builds a repository's Dataverse assembly heads and unit test projects, records a normalised warning baseline, then diffs the warnings and runs the unit tests after a change, with a short PASS, FAIL or INCOMPLETE report. Use before the first C# edit of a task, while fixing build errors, warnings or failing tests, and as the gate before reporting C# work as done.
---

# .NET build verification

Intended for `developer` and `developer-worker`, but usable by anyone working on C# in a Power Platform repository.

## Why

Existing projects can carry thousands of analyser warnings, so "no new warnings" can't be checked by eye. The scripts:

- build the agreed projects the same way every time: the heads in Release and the unit test projects in `UnitTest` (see `dataverse-plugins` for that layout), with `-v q -nologo --no-incremental`;
- normalise each warning to `file|code|message`, with a repository-relative path and no line or column, so moving code doesn't create noise;
- compare the warnings with the baseline as a multiset, so a second occurrence of an existing warning still counts as added;
- in a test project's build, count only the warnings MSBuild attributes to the test project, because that build repeats the warnings of everything it references;
- run the unit tests against that same build, holding one lock across the builds and the tests;
- print a short report and keep the full logs in a folder outside the repository.

## Scripts

Run them with PowerShell 7 from anywhere in the repository, for example `pwsh -NoProfile -File <this skill's folder>/scripts/Test-Change.ps1`. Each has `-?` help with every parameter.

| Script                                                               | Purpose                                                                                                                  |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [Find-VerificationProject.ps1](scripts/Find-VerificationProject.ps1) | Lists the candidate projects with a role, configuration and reason. Changes nothing                                      |
| [New-WarningBaseline.ps1](scripts/New-WarningBaseline.ps1)           | Builds the given projects and saves the warning baseline and the project list. Saves nothing if a build fails            |
| [Test-Change.ps1](scripts/Test-Change.ps1)                           | Rebuilds the recorded projects, diffs the warnings, runs the unit tests and prints `RESULT PASS`, `FAIL` or `INCOMPLETE` |
| [BuildVerification.psm1](scripts/BuildVerification.psm1)             | Functions shared by the scripts. Don't call it directly                                                                  |

Load [report.md](references/report.md) when you read a report, choose a `-PathFilter`, or need the exit codes.

## Procedure

1. **Find the projects.** Run `Find-VerificationProject.ps1`. It suggests:
   - **Head**: references the Dataverse SDK and has a Release configuration. Built in Release.
   - **UnitTests**: a test project, built in `UnitTest` if it declares it, otherwise Debug.

   It lists, without suggesting, **SharedCode** (a shared-code assembly with no Release configuration, which the test build compiles) and **OtherTests** (Reqnroll, SpecFlow or Playwright tests, which need an environment). Confirm the list with the user, as in [project-facts.md](../power-platform-standards/references/project-facts.md). Don't store it: the baseline records it.

2. **Take a baseline before the first C# edit.**

   ```powershell
   New-WarningBaseline.ps1 -Project 'src/Abc.Plugins/Abc.Plugins.csproj,src/Abc.Workflows/Abc.Workflows.csproj' -TestProject 'tests/Abc.UnitTests/Abc.UnitTests.csproj'
   ```

   - Take a fresh baseline for every task. Never reuse one from an earlier task or session.
   - If it prints `RESULT FAIL`, stop and report the failed build before changing anything. Stale `.projitems` entries and compile errors in the tests are common causes.
   - If the task adds a head or a test project, create the project first with no code, check that it builds, then include it in the baseline.

3. **Iterate with the cheapest run that answers the question.**
   - Build and warnings only: `Test-Change.ps1 -SkipTests -PathFilter '<files you changed>'`. Include test files.
   - The tests for one area, without a build: `Test-Change.ps1 -SkipBuild -TestFilter '<filter>'`. `dotnet test` compiles the test project itself, so its warnings aren't checked.
   - The tests for one area with the warnings in their files: `Test-Change.ps1 -PathFilter 'tests/Abc.UnitTests/Application/Inspections/*' -TestFilter 'FullyQualifiedName~Abc.UnitTests.Application.Inspections'`. It builds once and runs only the filtered tests.
4. **Run the gate** before reporting the change as done: `Test-Change.ps1` with no skip switches and no `-TestFilter`, plus `-PathFilter '<new and changed files>'`.
   - Only a bare `RESULT PASS` from this full run counts as verified.
   - `IN SCOPE` lists every warning in those files, new or old. New files must have none. Report any that remain in changed files.

## Rules

- **One build at a time per working tree.** Concurrent builds collide on the `obj` and `bin` folders. The scripts queue behind each other and print `WAITING`, but a build started any other way, by an IDE or a direct `dotnet build`, isn't queued. Never run two code-changing workers that build or test in the same working tree.
- **Same machine and SDK** for the baseline and the gate. The baseline's `<name>.json` records the commit, whether there were uncommitted changes, the SDK version and the projects.
- **Fix warnings; don't suppress them.** Add no `#pragma`, `[SuppressMessage]`, `.editorconfig` or `NoWarn` change to reach `PASS` unless the user has approved that specific suppression.
- **Trust the script output, not a summary of it.** Quote the `RESULT` line and any failure lines verbatim.
- **Output stays outside the repository**, in a folder for each checkout under the system temporary directory, which keeps the ten most recent runs. `-OutputDirectory` must also be outside the repository.
