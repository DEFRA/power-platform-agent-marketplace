<#
.SYNOPSIS
    Builds the given projects and saves a normalised warning baseline outside the repository.

.DESCRIPTION
    Builds each -Project in -Configuration (Release by default), then each -TestProject in -TestConfiguration
    (UnitTest by default), with "-v q -nologo --no-incremental -clp:ForceNoAlign". If any build fails it lists the
    first 20 distinct errors of each failed build and saves nothing; a failed run also removes any earlier baseline
    with the same name.

    Each warning is normalised to "file|code|message", with a repository-relative path and no line or column, and
    saved one line per occurrence, so that Test-Change.ps1 can diff the warnings as a multiset. For a test project,
    only the warnings that MSBuild attributes to the test project itself are kept. Its build repeats the warnings of
    the projects it references, and their own builds record those.

    <Name>.json records the projects and their configurations, the commit, whether there were uncommitted changes and
    the .NET SDK version. Test-Change.ps1 builds exactly those projects.

    Run it before the first C# edit of a task. It prints counts only; the full logs stay in the output directory.

.PARAMETER Project
    The projects to build in -Configuration, usually the plug-in and workflow assembly heads. Give paths relative to
    the repository root, separated by commas. Find-VerificationProject.ps1 suggests them.

.PARAMETER TestProject
    The unit test projects to build in -TestConfiguration. Test-Change.ps1 runs their tests. Give paths relative to
    the repository root, separated by commas.

.PARAMETER Configuration
    The configuration for -Project. Defaults to Release.

.PARAMETER TestConfiguration
    The configuration for -TestProject. Defaults to UnitTest.

.PARAMETER Name
    The baseline name: letters, digits, dots, hyphens and underscores. Defaults to "baseline".

.PARAMETER OutputDirectory
    Where to save the baseline. Defaults to a folder for this checkout under the system temporary directory. It must
    be outside the repository.

.PARAMETER RepositoryRoot
    The repository root. Defaults to the git repository that contains the current location.

.EXAMPLE
    ./New-WarningBaseline.ps1 -Project 'src/Abc.Plugins/Abc.Plugins.csproj,src/Abc.Workflows/Abc.Workflows.csproj' -TestProject 'tests/Abc.UnitTests/Abc.UnitTests.csproj'

    Builds both heads in Release and the unit test project in UnitTest, and saves the baseline named "baseline".

.EXAMPLE
    ./New-WarningBaseline.ps1 -Project 'src/Abc.Plugins/Abc.Plugins.csproj' -TestProject 'tests/Abc.UnitTests/Abc.UnitTests.csproj' -TestConfiguration Debug

    For a test project that has no UnitTest configuration.
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Project,

    [Parameter(Mandatory = $true)]
    [string[]]$TestProject,

    [string]$Configuration = 'Release',

    [string]$TestConfiguration = 'UnitTest',

    [ValidatePattern('^[\w.-]+$')]
    [string]$Name = 'baseline',

    [string]$OutputDirectory,

    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildVerification.psm1')

$root = Resolve-RepositoryRoot -RepositoryRoot $RepositoryRoot
$projects = @(
    foreach ($path in (Split-ListArgument $Project)) {
        [pscustomobject]@{ Path = ConvertTo-RepositoryPath -RepositoryRoot $root -Path $path; Configuration = $Configuration; Role = 'Head' }
    }
    foreach ($path in (Split-ListArgument $TestProject)) {
        [pscustomobject]@{ Path = ConvertTo-RepositoryPath -RepositoryRoot $root -Path $path; Configuration = $TestConfiguration; Role = 'UnitTests' }
    }
)

$directory = Get-VerificationDirectory -RepositoryRoot $root -OutputDirectory $OutputDirectory
$baselinePath = Join-Path $directory "$Name.warnings.txt"
$metadataPath = Join-Path $directory "$Name.json"
$logDirectory = Join-Path $directory "$Name-logs"

$lock = Enter-VerificationLock -RepositoryRoot $root
try {
    Remove-Item -LiteralPath $baselinePath, $metadataPath, $logDirectory -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $builds = @(Invoke-VerificationBuild -RepositoryRoot $root -Project $projects -LogDirectory $logDirectory)
}
finally {
    Exit-VerificationLock -Lock $lock
}

foreach ($build in $builds) {
    'BUILD     {0,-24} {1,-9} {2} warnings' -f $build.Name, ($build.Succeeded ? 'succeeded' : 'FAILED'), $build.Warnings.Count
}

$failed = @($builds | Where-Object { -not $_.Succeeded })
if ($failed.Count -gt 0) {
    foreach ($build in $failed) {
        "ERRORS    $($build.Name) (first 20; full log: $($build.Log))"
        $build.Errors | Select-Object -Unique -First 20 | ForEach-Object { "  $_" }
    }

    'RESULT    FAIL - baseline not saved. Report the failed build before changing any code. Stale .projitems entries and compile errors in the tests are common causes.'
    exit 1
}

[string[]]$keys = @($builds | ForEach-Object { $_.Warnings })
[Array]::Sort($keys, [StringComparer]::Ordinal)
[IO.File]::WriteAllLines($baselinePath, $keys)

$state = Get-RepositoryState -RepositoryRoot $root
[ordered]@{
    name               = $Name
    createdUtc         = [DateTime]::UtcNow.ToString('o')
    commit             = $state.Commit
    uncommittedChanges = $state.HasUncommittedChanges
    sdk                = $state.Sdk
    warnings           = $keys.Count
    projects           = @($projects | ForEach-Object { [ordered]@{ path = $_.Path; configuration = $_.Configuration; role = $_.Role } })
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding utf8

$distinct = (Get-DiagnosticCount -Key $keys).Count
'BASELINE  {0} warnings ({1} distinct) | commit {2}{3} | SDK {4}' -f $keys.Count, $distinct, $state.Commit, ($state.HasUncommittedChanges ? ' + uncommitted changes' : ''), $state.Sdk
"SAVED     $baselinePath"
exit 0
