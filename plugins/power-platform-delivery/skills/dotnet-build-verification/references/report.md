# Reading the verification report

`New-WarningBaseline.ps1` prints a `BUILD` line for each project, then `BASELINE` and `SAVED`, or the errors and `RESULT FAIL`. `Test-Change.ps1` prints the lines below, in this order.

| Line | Meaning |
| --- | --- |
| `BUILD` | The result for each recorded project, heads first. A failed build is followed by `ERRORS`: the first 20 distinct errors from every project in that build, and the path of the full log. Tests don't run after a failed build |
| `WARNINGS baseline N -> current M \| added A \| removed R` | Up to 30 added warnings follow, each with its occurrence count. Any added warning fails the run. Removed warnings are grouped by file. They're expected when code is deleted or a warning is fixed |
| `IN SCOPE` | Every current warning, new or old, in files that match `-PathFilter`. With `-SkipBuild` it says `not checked` |
| `TESTS total \| passed \| failed \| skipped` | The totals across every test project. Up to 30 failed tests follow, each with the first line of its message. `skipped` counts tests that are marked to be skipped. `produced no results` means `dotnet test` wrote no TRX file, usually because of a compile error on a `-SkipBuild` run; its errors are listed |
| `RESULT` | `PASS`, `FAIL` or `INCOMPLETE`, with the reasons. A note such as `(build skipped; tests filtered)` marks a partial run, which is never the gate |
| `DETAILS` | The run folder. It holds the build and test logs, the TRX files, `warnings-added.txt` and `warnings-removed.txt`. Read them only when the summary isn't enough |

## Exit codes

| Code | Result | Meaning |
| --- | --- | --- |
| 0 | `PASS` | Every build is green, no warnings were added and no tests failed |
| 1 | `FAIL` | A build error, added warnings, failed tests, or a test project that produced no results |
| 2 | `INCOMPLETE` | No baseline with that name, a recorded project that no longer exists, no tests ran or matched `-TestFilter`, `-PathFilter` with `-SkipBuild`, or both skip switches |

`New-WarningBaseline.ps1` exits 0 when it saves the baseline and 1 when a build fails.

## Path filters

- Use repository-relative paths with forward slashes and PowerShell `-like` wildcards. Separate several with commas inside one quoted string, for example `-PathFilter 'src/Abc.Application/Inspections/*,tests/Abc.UnitTests/Application/Inspections/*'`.
- Prefer exact folders or file names. A broad fragment such as `*Inspection*` also matches unrelated files, such as `InspectionScheduleReport.cs`.
- A warning in a test file appears once, because only the test project's own warnings are counted. A warning in a shared project appears once for each head that compiles it.
