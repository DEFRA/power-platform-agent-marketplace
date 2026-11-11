<#
.SYNOPSIS
    Verifies a change: rebuilds the projects recorded in the baseline, diffs their warnings against it and runs the
    unit tests, then prints a compact report.

.DESCRIPTION
    1. Builds the projects that New-WarningBaseline.ps1 recorded, in the same configurations and in the same way. A
       compile error in any of them fails the build phase.
    2. Diffs the normalised warnings ("file|code|message") against the baseline as a multiset, so a second
       occurrence of an existing warning in the same file still counts as added.
    3. Optionally lists every current warning in files that match -PathFilter, whether new or not.
    4. Runs each recorded test project with "dotnet test --no-build", against the build from step 1, and summarises
       the TRX results. With -SkipBuild there is no build to reuse, so dotnet test compiles the projects itself and
       their warnings aren't diffed.

    One lock is held across the builds and the test runs, and runs in the same checkout queue rather than overlap.
    Full logs, the TRX files and the complete lists of added and removed warnings go to a run folder outside the
    repository, printed on the last line. The ten most recent run folders are kept.

    Only a bare "RESULT    PASS" means that the gate passed. A run with -SkipBuild, -SkipTests or -TestFilter labels
    its RESULT line, for example "RESULT    PASS (build skipped; tests filtered)".

    Exit codes: 0 PASS; 1 FAIL (a build error, added warnings, failed tests or a test run with no results);
    2 INCOMPLETE (no baseline, a recorded project that no longer exists, no tests ran or matched -TestFilter,
    -PathFilter with -SkipBuild, or both skip switches).

.PARAMETER BaselineName
    The baseline that New-WarningBaseline.ps1 saved. Defaults to "baseline".

.PARAMETER PathFilter
    Repository-relative wildcard patterns with forward slashes, separated by commas, for example
    'src/Abc.Application/Inspections/*,tests/Abc.UnitTests/Application/Inspections/*'. Prefer exact folders or file
    names to broad fragments. It needs the build: with -SkipBuild it isn't checked and the result is INCOMPLETE.

.PARAMETER TestFilter
    A dotnet test --filter expression, for example 'FullyQualifiedName~Abc.UnitTests.Application.Inspections'.

.PARAMETER SkipBuild
    Skips the builds and the warning diff.

.PARAMETER SkipTests
    Skips the unit tests.

.PARAMETER OutputDirectory
    The folder that holds the baseline. Defaults to the same folder for this checkout as New-WarningBaseline.ps1.

.PARAMETER RepositoryRoot
    The repository root. Defaults to the git repository that contains the current location.

.EXAMPLE
    ./Test-Change.ps1

    The full gate: builds every recorded project, diffs the warnings and runs every unit test.

.EXAMPLE
    ./Test-Change.ps1 -SkipTests -PathFilter 'src/Abc.Application/Inspections/*'

    Builds and diffs the warnings only, and lists every warning in the files you changed.

.EXAMPLE
    ./Test-Change.ps1 -PathFilter 'tests/Abc.UnitTests/Application/Inspections/*' -TestFilter 'FullyQualifiedName~Abc.UnitTests.Application.Inspections'

    Builds once, runs only the tests for one area and lists the warnings in their files.
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidatePattern('^[\w.-]+$')]
    [string]$BaselineName = 'baseline',

    [string[]]$PathFilter,

    [string]$TestFilter,

    [switch]$SkipBuild,

    [switch]$SkipTests,

    [string]$OutputDirectory,

    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildVerification.psm1')

function Format-CountedKey {
    param(
        [AllowEmptyCollection()]
        [object[]]$Item,

        [string]$Prefix = ''
    )

    foreach ($entry in $Item) {
        '  {0}{1} x {2}' -f $Prefix, $entry.Count, $entry.Key
    }
}

$PathFilter = Split-ListArgument $PathFilter
$root = Resolve-RepositoryRoot -RepositoryRoot $RepositoryRoot
$directory = Get-VerificationDirectory -RepositoryRoot $root -OutputDirectory $OutputDirectory
$baselinePath = Join-Path $directory "$BaselineName.warnings.txt"
$metadataPath = Join-Path $directory "$BaselineName.json"

if (-not (Test-Path -LiteralPath $baselinePath) -or -not (Test-Path -LiteralPath $metadataPath)) {
    "RESULT    INCOMPLETE - no baseline named '$BaselineName' in $directory. Run New-WarningBaseline.ps1 first."
    exit 2
}

$projects = @((Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json).projects |
        Where-Object { $_ } |
        ForEach-Object { [pscustomobject]@{ Path = $_.path; Configuration = $_.configuration; Role = $_.role } })
$missing = @($projects | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_.Path) -PathType Leaf) })
if ($projects.Count -eq 0 -or $missing.Count -gt 0) {
    $problem = if ($projects.Count -eq 0) { 'records no projects' } else { "records projects that no longer exist: $($missing.Path -join ', ')" }
    "RESULT    INCOMPLETE - baseline '$BaselineName' $problem. Take a new baseline with New-WarningBaseline.ps1."
    exit 2
}

$runDirectory = Join-Path $directory ('run-{0:yyyyMMdd-HHmmss-fff}-{1}' -f (Get-Date), $PID)
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
Remove-OldVerificationRun -Directory $directory

$buildFailed = $false
$failures = [Collections.Generic.List[string]]::new()
$incomplete = [Collections.Generic.List[string]]::new()
$partial = [Collections.Generic.List[string]]::new()

# One lock covers the builds and the test runs, so that dotnet test --no-build tests exactly what was built.
$lock = $null
if (-not ($SkipBuild -and $SkipTests)) {
    $lock = Enter-VerificationLock -RepositoryRoot $root
}

try {
    if ($SkipBuild) {
        $partial.Add('build skipped')
        'BUILD     skipped'

        if ($PathFilter.Count -gt 0) {
            $incomplete.Add('-PathFilter was not checked because the build was skipped')
            'IN SCOPE  not checked: -PathFilter needs the build, which -SkipBuild skips'
        }
    }
    else {
        $builds = @(Invoke-VerificationBuild -RepositoryRoot $root -Project $projects -LogDirectory $runDirectory)

        'BUILD     ' + (($builds | ForEach-Object { '{0} {1}' -f $_.Name, ($_.Succeeded ? 'succeeded' : 'FAILED') }) -join ' | ')

        foreach ($build in @($builds | Where-Object { -not $_.Succeeded })) {
            $buildFailed = $true
            $failures.Add("$($build.Name) build failed")
            "ERRORS    $($build.Name) (first 20; full log: $($build.Log))"
            $build.Errors | Select-Object -Unique -First 20 | ForEach-Object { "  $_" }
        }

        if (-not $buildFailed) {
            [string[]]$currentKeys = @($builds | ForEach-Object { $_.Warnings })
            [string[]]$baselineKeys = [IO.File]::ReadAllLines($baselinePath)
            $diff = Compare-DiagnosticCount -Baseline (Get-DiagnosticCount -Key $baselineKeys) -Current (Get-DiagnosticCount -Key $currentKeys)
            $addedCount = [int](($diff.Added | Measure-Object -Property Count -Sum).Sum)
            $removedCount = [int](($diff.Removed | Measure-Object -Property Count -Sum).Sum)
            'WARNINGS  baseline {0} -> current {1} | added {2} | removed {3}' -f $baselineKeys.Count, $currentKeys.Count, $addedCount, $removedCount

            if ($addedCount -gt 0) {
                $failures.Add("$addedCount added warning(s)")
                Format-CountedKey -Item $diff.Added -Prefix '+' | Set-Content -LiteralPath (Join-Path $runDirectory 'warnings-added.txt') -Encoding utf8
                Format-CountedKey -Item ($diff.Added | Select-Object -First 30) -Prefix '+'
                if ($diff.Added.Count -gt 30) {
                    "  ... $($diff.Added.Count - 30) more in warnings-added.txt"
                }
            }

            if ($removedCount -gt 0) {
                Format-CountedKey -Item $diff.Removed -Prefix '-' | Set-Content -LiteralPath (Join-Path $runDirectory 'warnings-removed.txt') -Encoding utf8
                $byFile = $diff.Removed |
                    Group-Object { ($_.Key -split '\|', 2)[0] } |
                    ForEach-Object { [pscustomobject]@{ Key = $_.Name; Count = [int](($_.Group | Measure-Object -Property Count -Sum).Sum) } } |
                    Sort-Object Count -Descending
                '  removed, by file (top 10; full list in warnings-removed.txt):'
                Format-CountedKey -Item ($byFile | Select-Object -First 10) -Prefix '-'
            }

            if ($PathFilter.Count -gt 0) {
                $inScope = @($currentKeys | Where-Object {
                        $file = ($_ -split '\|', 2)[0]
                        @($PathFilter | Where-Object { $file -like $_ }).Count -gt 0
                    })
                'IN SCOPE  {0} warning(s) in files matching: {1}' -f $inScope.Count, ($PathFilter -join ', ')
                $grouped = $inScope | Group-Object -CaseSensitive | ForEach-Object { [pscustomobject]@{ Key = $_.Name; Count = $_.Count } } | Sort-Object Key
                Format-CountedKey -Item ($grouped | Select-Object -First 30)
            }
        }
    }

    $testProjects = @($projects | Where-Object Role -EQ 'UnitTests')
    if ($SkipTests) {
        $partial.Add('tests skipped')
        'TESTS     skipped'
    }
    elseif ($buildFailed) {
        'TESTS     not run because a build failed; fix the build first'
    }
    elseif ($testProjects.Count -eq 0) {
        $incomplete.Add('the baseline records no test project')
        'TESTS     none: the baseline records no test project'
    }
    else {
        $total, $passed, $failed, $skipped = 0, 0, 0, 0
        $failedTests = [Collections.Generic.List[object]]::new()
        $noResults = [Collections.Generic.List[string]]::new()
        $index = 0

        foreach ($testProject in $testProjects) {
            $index++
            $name = [IO.Path]::GetFileNameWithoutExtension($testProject.Path)
            $trxName = "$index-$name.trx"
            $testLog = Join-Path $runDirectory "$index-$name.test.log"
            $testArguments = @(
                'test'
                (Join-Path $root $testProject.Path)
                '--configuration'
                $testProject.Configuration
                '-nologo'
                '-clp:ForceNoAlign'
                '--logger'
                "trx;LogFileName=$trxName"
                '--results-directory'
                $runDirectory
            )
            if (-not $SkipBuild) {
                $testArguments += '--no-build'
            }

            if ($TestFilter) {
                $testArguments += @('--filter', $TestFilter)
            }

            & dotnet @testArguments *> $testLog
            $trxPath = Join-Path $runDirectory $trxName

            if (Test-Path -LiteralPath $trxPath) {
                $result = Read-TestResult -Path $trxPath
                $total += $result.Total
                $passed += $result.Passed
                $failed += $result.Failed
                $skipped += $result.Skipped
                $failedTests.AddRange([object[]]$result.FailedTests)
            }
            elseif (-not (Select-String -LiteralPath $testLog -SimpleMatch 'No test matches the given testcase filter' -Quiet)) {
                $noResults.Add($name)
                "TESTS     $name produced no results (full log: $testLog)"
                @(ConvertTo-DiagnosticKey -Path $testLog -RepositoryRoot $root -Severity error -MatchedOnly) |
                    Select-Object -Unique -First 20 |
                    ForEach-Object { "  $_" }
            }
        }

        'TESTS     total {0} | passed {1} | failed {2} | skipped {3}' -f $total, $passed, $failed, $skipped
        foreach ($test in ($failedTests | Select-Object -First 30)) {
            "  FAILED $($test.Name): $($test.Message)"
        }

        if ($failed -gt 0) {
            $failures.Add("$failed failed test(s)")
        }

        if ($noResults.Count -gt 0) {
            $failures.Add("no test results from $($noResults -join ', ')")
        }
        elseif ($total -eq 0) {
            $incomplete.Add(($TestFilter ? "no tests matched -TestFilter '$TestFilter'" : 'no tests ran'))
        }
    }
}
finally {
    if ($lock) {
        Exit-VerificationLock -Lock $lock
    }
}

if ($TestFilter -and -not $SkipTests) {
    $partial.Add('tests filtered')
}

if ($SkipBuild -and $SkipTests) {
    $incomplete.Add('nothing was verified')
}

# Only a bare PASS means that the gate passed.
$partialNote = if ($partial.Count -gt 0) { " ($($partial -join '; '))" } else { '' }

if ($failures.Count -gt 0) {
    "RESULT    FAIL$partialNote - $($failures -join '; ')"
    $exitCode = 1
}
elseif ($incomplete.Count -gt 0) {
    "RESULT    INCOMPLETE$partialNote - $($incomplete -join '; ')"
    $exitCode = 2
}
else {
    "RESULT    PASS$partialNote"
    $exitCode = 0
}

"DETAILS   $runDirectory"
exit $exitCode
