#requires -Version 7.0

# Shared functions for Find-VerificationProject.ps1, New-WarningBaseline.ps1 and Test-Change.ps1.

Set-StrictMode -Version Latest

$script:DataverseReferences = @(
    'Microsoft.CrmSdk.CoreAssemblies'
    'Microsoft.CrmSdk.Workflow'
    'Microsoft.Xrm.Sdk'
    'Microsoft.Xrm.Sdk.Workflow'
    'Microsoft.PowerApps.MSBuild.Plugin'
)
$script:TestReferences = @('Microsoft.NET.Test.Sdk', 'MSTest.Sdk')
$script:EnvironmentTestReferences = @('Reqnroll', 'SpecFlow', 'Microsoft.Playwright')
$script:SkippedFolders = @('bin', 'obj', 'node_modules', '.git', '.vs')

function Resolve-RepositoryRoot {
    <#
    .SYNOPSIS
        Returns the full path of -RepositoryRoot or, when it is empty, of the git repository that contains the
        current location.
    #>
    param(
        [string]$RepositoryRoot
    )

    if ($RepositoryRoot) {
        $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepositoryRoot)
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            throw "The repository root doesn't exist: $path"
        }

        return [IO.Path]::GetFullPath($path).TrimEnd('\', '/')
    }

    $root = git -C (Get-Location).Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        throw 'The current location is not inside a git repository. Run the script from inside the repository, or pass -RepositoryRoot.'
    }

    [IO.Path]::GetFullPath("$root".Trim()).TrimEnd('\', '/')
}

function Get-CheckoutId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($RepositoryRoot.ToLowerInvariant()))
    }
    finally {
        $sha.Dispose()
    }

    -join ($hash[0..3] | ForEach-Object { $_.ToString('x2') })
}

function Get-VerificationDirectory {
    <#
    .SYNOPSIS
        Returns, and creates, the folder for baselines and run logs. It must be outside the repository.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [string]$OutputDirectory
    )

    if (-not $OutputDirectory) {
        # One folder per clone or worktree, so that baselines from different checkouts never mix.
        $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) "dotnet-build-verification/$(Get-CheckoutId -RepositoryRoot $RepositoryRoot)"
    }

    $fullPath = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)).TrimEnd('\', '/')
    $root = $RepositoryRoot.TrimEnd('\', '/')
    if ($fullPath -ieq $root -or $fullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The output directory must be outside the repository: $fullPath"
    }

    New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    $fullPath
}

function Enter-VerificationLock {
    <#
    .SYNOPSIS
        Waits until no other verification run is using this checkout, then takes the lock. Concurrent builds in one
        working tree collide on the obj and bin folders, so runs queue here instead. Release it with
        Exit-VerificationLock in a finally block.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [int]$TimeoutMinutes = 30
    )

    $mutex = [Threading.Mutex]::new($false, "Local\dotnet-build-verification-$(Get-CheckoutId -RepositoryRoot $RepositoryRoot)")
    try {
        if (-not $mutex.WaitOne(0)) {
            Write-Host 'WAITING   another verification run is using this checkout'
            if (-not $mutex.WaitOne([TimeSpan]::FromMinutes($TimeoutMinutes))) {
                $mutex.Dispose()
                throw "Timed out after $TimeoutMinutes minutes waiting for another verification run in this checkout."
            }
        }
    }
    catch [Threading.AbandonedMutexException] {
        # The previous holder exited without releasing the lock, so ownership has passed to this run.
    }

    $mutex
}

function Exit-VerificationLock {
    param(
        [Parameter(Mandatory = $true)]
        [Threading.Mutex]$Lock
    )

    $Lock.ReleaseMutex()
    $Lock.Dispose()
}

function Remove-OldVerificationRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [int]$Keep = 10
    )

    Get-ChildItem -LiteralPath $Directory -Directory |
        Where-Object Name -Match '^run-\d{8}-\d{6}-\d{3}-\d+$' |
        Sort-Object Name -Descending |
        Select-Object -Skip $Keep |
        Remove-Item -Recurse -Force
}

function ConvertTo-RepositoryPath {
    <#
    .SYNOPSIS
        Converts a project path, absolute or relative to the repository root, to a repository-relative path with
        forward slashes. The project must exist inside the repository.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $RepositoryRoot $Path }
    $fullPath = [IO.Path]::GetFullPath($candidate)
    $relative = [IO.Path]::GetRelativePath($RepositoryRoot, $fullPath) -replace '\\', '/'
    if ($relative -eq '..' -or $relative.StartsWith('../') -or [IO.Path]::IsPathRooted($relative)) {
        throw "The project must be inside the repository: $Path"
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "The project doesn't exist: $relative"
    }

    $relative
}

function Split-ListArgument {
    <#
    .SYNOPSIS
        Splits comma-separated values. pwsh -File passes a list such as "a,b" as one string.
    #>
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Value
    )

    @($Value | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-ProjectInfo {
    <#
    .SYNOPSIS
        Reads what discovery needs from a project file: its package and assembly references, whether it is a test
        project, and the build configurations it declares.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    [xml]$xml = [IO.File]::ReadAllText($Path)
    $references = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($node in $xml.SelectNodes("//*[local-name()='PackageReference' or local-name()='Reference']")) {
        [void]$references.Add(($node.GetAttribute('Include') -split ',')[0].Trim())
    }

    $sdk = $xml.DocumentElement.GetAttribute('Sdk')
    if ($sdk) {
        [void]$references.Add(($sdk -split '/')[0])
    }

    $configurations = [Collections.Generic.List[string]]::new()
    foreach ($node in $xml.SelectNodes("//*[local-name()='Configurations']")) {
        $configurations.AddRange([string[]]@($node.InnerText -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }))
    }

    if ($configurations.Count -eq 0) {
        # Without <Configurations>, a project has Debug and Release, plus any configuration that a condition names,
        # such as '$(Configuration)|$(Platform)' == 'Release|AnyCPU'.
        $configurations.AddRange([string[]]@('Debug', 'Release'))
        foreach ($node in $xml.SelectNodes("//@*[local-name()='Condition']")) {
            foreach ($match in [regex]::Matches($node.Value, "'\`$\(Configuration\)(?:\|\`$\(Platform\))?'\s*[!=]=\s*'(?<name>[^'|]+)")) {
                $configurations.Add($match.Groups['name'].Value)
            }
        }
    }

    $isTestProject = $xml.SelectSingleNode("//*[local-name()='IsTestProject']")
    [pscustomobject]@{
        References     = $references
        IsTest         = ($null -ne $isTestProject -and $isTestProject.InnerText.Trim() -eq 'true') -or @($script:TestReferences | Where-Object { $references.Contains($_) }).Count -gt 0
        Configurations = @($configurations | Select-Object -Unique)
    }
}

function Find-VerificationProject {
    <#
    .SYNOPSIS
        Lists the C# projects that reference the Dataverse SDK, and the test projects, with the role and
        configuration the verification build would use for each. This is discovery only: confirm the list with
        the user.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    $files = [Collections.Generic.List[string]]::new()
    $folders = [Collections.Generic.Stack[string]]::new()
    $folders.Push($RepositoryRoot)
    while ($folders.Count -gt 0) {
        $folder = $folders.Pop()
        $files.AddRange([IO.Directory]::GetFiles($folder, '*.csproj'))
        foreach ($child in [IO.Directory]::GetDirectories($folder)) {
            if ([IO.Path]::GetFileName($child) -notin $script:SkippedFolders) {
                $folders.Push($child)
            }
        }
    }

    foreach ($file in ($files | Sort-Object)) {
        $info = Get-ProjectInfo -Path $file
        $dataverse = @($script:DataverseReferences | Where-Object { $info.References.Contains($_) }).Count -gt 0

        if ($info.IsTest) {
            $configuration = if ($info.Configurations -contains 'UnitTest') { 'UnitTest' } else { 'Debug' }
            $environment = @($script:EnvironmentTestReferences | Where-Object { $info.References.Contains($_) })
            if ($environment.Count -gt 0) {
                $role, $suggested = 'OtherTests', $false
                $reason = "References $($environment -join ', '). Acceptance and integration tests need an environment, so leave them out"
            }
            else {
                $role, $suggested = 'UnitTests', $true
                $reason = 'A test project that needs no environment'
            }
        }
        elseif ($dataverse -and $info.Configurations -contains 'Release') {
            $role, $suggested, $configuration = 'Head', $true, 'Release'
            $reason = 'References the Dataverse SDK and builds in Release'
        }
        elseif ($dataverse) {
            $role, $suggested, $configuration = 'SharedCode', $false, ($info.Configurations -join ';')
            $reason = 'References the Dataverse SDK but has no Release configuration. The unit test build compiles it'
        }
        else {
            continue
        }

        [pscustomobject]@{
            Path          = [IO.Path]::GetRelativePath($RepositoryRoot, $file) -replace '\\', '/'
            Role          = $role
            Configuration = $configuration
            Suggested     = $suggested
            Reason        = $reason
        }
    }
}

function ConvertTo-DiagnosticKey {
    <#
    .SYNOPSIS
        Normalises MSBuild diagnostics to "file|code|message": repository-relative paths with forward slashes, and no
        line numbers, columns, node prefixes or project suffixes. Unparsed lines are kept as "<unparsed>||<line>"
        unless -MatchedOnly is set.

        With -Project (a repository-relative path with forward slashes), only diagnostics that MSBuild attributes to
        that project, through its trailing "[project]" suffix, are returned. Unparsed lines can't be attributed, so
        they are dropped.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [ValidateSet('warning', 'error')]
        [string]$Severity,

        [switch]$MatchedOnly,

        [string]$Project
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $pattern = '^(?<origin>.*?)(?:\((?<location>[\d,]+)\))?\s*:\s*' + $Severity + '(?:\s+(?<code>[^\s:]+))?\s*:\s*(?<message>.*?)(?:\s+\[(?<project>[^\[\]]+)\])?\s*$'
    $rootPattern = ([regex]::Escape($RepositoryRoot.TrimEnd('\', '/')) -replace '\\\\', '[\\/]') + '[\\/]'

    foreach ($rawLine in [IO.File]::ReadLines($Path)) {
        $line = ($rawLine -replace '^\s*\d+(?::\d+)?>', '') -ireplace $rootPattern, ''
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match $pattern) {
            if ($Project) {
                # MSBuild appends "::TargetFramework=..." to the project of a multi-targeted build.
                $attributedTo = ("$($Matches['project'])" -replace '::.*$', '') -replace '\\', '/'
                if ($attributedTo -ine $Project) {
                    continue
                }
            }

            $origin = $Matches['origin'].Trim() -replace '\\', '/'
            '{0}|{1}|{2}' -f $origin, $Matches['code'], $Matches['message'].Trim()
        }
        elseif (-not $MatchedOnly -and -not $Project) {
            '<unparsed>||{0}' -f $line.Trim()
        }
    }
}

function Invoke-VerificationBuild {
    <#
    .SYNOPSIS
        Builds each project in its configuration and returns whether it succeeded, with its normalised warnings and
        errors. A test project's warnings are only those MSBuild attributes to the test project, because its build
        repeats the warnings of the heads it references. Errors come from every project in the build.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [object[]]$Project,

        [Parameter(Mandatory = $true)]
        [string]$LogDirectory
    )

    $index = 0
    foreach ($item in $Project) {
        $index++
        $name = [IO.Path]::GetFileNameWithoutExtension($item.Path)
        $prefix = Join-Path $LogDirectory "$index-$name"

        # File loggers record each diagnostic once; the console logger repeats them in its summary.
        & dotnet build (Join-Path $RepositoryRoot $item.Path) --configuration $item.Configuration -v q -nologo --no-incremental '-clp:ForceNoAlign' "-flp1:logfile=$prefix.warnings.log;warningsonly;forcenoalign;nosummary" "-flp2:logfile=$prefix.errors.log;errorsonly;forcenoalign;nosummary" *> "$prefix.build.log"
        $exitCode = $LASTEXITCODE
        $attributedTo = if ($item.Role -eq 'UnitTests') { $item.Path } else { $null }

        [pscustomobject]@{
            Name      = $name
            Path      = $item.Path
            Succeeded = $exitCode -eq 0
            Warnings  = @(ConvertTo-DiagnosticKey -Path "$prefix.warnings.log" -RepositoryRoot $RepositoryRoot -Severity warning -Project $attributedTo)
            Errors    = @(ConvertTo-DiagnosticKey -Path "$prefix.errors.log" -RepositoryRoot $RepositoryRoot -Severity error)
            Log       = "$prefix.build.log"
        }
    }
}

function Get-DiagnosticCount {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Key
    )

    $counts = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
    foreach ($item in $Key) {
        if ($null -eq $item) {
            continue
        }

        $existing = 0
        [void]$counts.TryGetValue($item, [ref]$existing)
        $counts[$item] = $existing + 1
    }

    # The unary comma stops the pipeline from enumerating the dictionary into key/value pairs.
    , $counts
}

function Compare-DiagnosticCount {
    <#
    .SYNOPSIS
        Diffs two diagnostic multisets. A key whose count rises is added; a key whose count falls is removed.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [Collections.Generic.Dictionary[string, int]]$Baseline,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [Collections.Generic.Dictionary[string, int]]$Current
    )

    $added = @(foreach ($entry in $Current.GetEnumerator()) {
            $before = 0
            [void]$Baseline.TryGetValue($entry.Key, [ref]$before)
            if ($entry.Value -gt $before) {
                [pscustomobject]@{ Key = $entry.Key; Count = $entry.Value - $before }
            }
        })

    $removed = @(foreach ($entry in $Baseline.GetEnumerator()) {
            $after = 0
            [void]$Current.TryGetValue($entry.Key, [ref]$after)
            if ($entry.Value -gt $after) {
                [pscustomobject]@{ Key = $entry.Key; Count = $entry.Value - $after }
            }
        })

    [pscustomobject]@{
        Added   = @($added | Sort-Object Key)
        Removed = @($removed | Sort-Object Key)
    }
}

function Read-TestResult {
    <#
    .SYNOPSIS
        Summarises a TRX file: the totals, and the name and first message line of each failed test.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    [xml]$trx = [IO.File]::ReadAllText($Path)
    $namespaces = [Xml.XmlNamespaceManager]::new($trx.NameTable)
    $namespaces.AddNamespace('t', 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010')
    $counters = $trx.SelectSingleNode('//t:ResultSummary/t:Counters', $namespaces)

    $failedTests = foreach ($result in $trx.SelectNodes('//t:Results/t:UnitTestResult[@outcome!="Passed" and @outcome!="NotExecuted"]', $namespaces)) {
        $message = $result.SelectSingleNode('t:Output/t:ErrorInfo/t:Message', $namespaces)
        [pscustomobject]@{
            Name    = $result.GetAttribute('testName')
            Message = if ($message) { ($message.InnerText.Trim() -split '\r?\n')[0] } else { '' }
        }
    }

    $failed = 0
    foreach ($counter in 'failed', 'error', 'timeout', 'aborted') {
        $failed += [int]$counters.GetAttribute($counter)
    }

    # Some frameworks record skipped tests as NotExecuted results but leave the notExecuted counter at zero.
    $total = [int]$counters.GetAttribute('total')
    [pscustomobject]@{
        Total       = $total
        Passed      = [int]$counters.GetAttribute('passed')
        Failed      = $failed
        Skipped     = $total - [int]$counters.GetAttribute('executed')
        FailedTests = @($failedTests)
    }
}

function Get-RepositoryState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    # --no-optional-locks stops git status from refreshing the index file.
    $commit = git -C $RepositoryRoot rev-parse --short HEAD 2>$null
    $changes = git -C $RepositoryRoot --no-optional-locks status --porcelain 2>$null

    [pscustomobject]@{
        Commit                = "$commit".Trim()
        HasUncommittedChanges = [bool]$changes
        Sdk                   = "$(dotnet --version)".Trim()
    }
}

Export-ModuleMember -Function Resolve-RepositoryRoot, Get-VerificationDirectory, Enter-VerificationLock, Exit-VerificationLock, Remove-OldVerificationRun, ConvertTo-RepositoryPath, Split-ListArgument, Get-ProjectInfo, Find-VerificationProject, ConvertTo-DiagnosticKey, Invoke-VerificationBuild, Get-DiagnosticCount, Compare-DiagnosticCount, Read-TestResult, Get-RepositoryState
