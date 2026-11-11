# Shared set-up for the dotnet-build-verification tests. Pester runs only *.Tests.ps1 files, so this file isn't a test.
# It stands in for the dotnet CLI with a global function, which takes precedence over the real executable, and builds a
# small git repository of project files in TestDrive.

$pluginRoot = $PSScriptRoot
while (-not (Test-Path -LiteralPath (Join-Path $pluginRoot 'plugin.json'))) {
    $pluginRoot = Split-Path -Parent $pluginRoot
    if (-not $pluginRoot) {
        throw 'plugin.json not found above the tests folder.'
    }
}

$script:ScriptsFolder = Join-Path $pluginRoot 'skills/dotnet-build-verification/scripts'

function global:dotnet {
    # Builds write the fixture warnings and errors to the file loggers; tests write the fixture TRX file.
    $arguments = @($args | ForEach-Object { "$_" })
    $global:FakeDotnet.Calls.Add($arguments -join ' ')
    $global:LASTEXITCODE = 0

    if ($arguments[0] -eq '--version') {
        '10.0.100'
        return
    }

    $name = [IO.Path]::GetFileNameWithoutExtension($arguments[1])
    if ($arguments[0] -eq 'build') {
        $build = $global:FakeDotnet.Builds[$name] ?? @{}
        foreach ($logger in @{ Switch = 'flp1'; Key = 'Warnings' }, @{ Switch = 'flp2'; Key = 'Errors' }) {
            $argument = @($arguments | Where-Object { $_ -like "-$($logger.Switch):logfile=*" })[0]
            $path = ($argument.Substring("-$($logger.Switch):logfile=".Length) -split ';')[0]
            [string[]]$lines = @($build[$logger.Key] | Where-Object { $_ } | ForEach-Object { $_.Replace('{root}', $global:FakeDotnet.Root) })
            [IO.File]::WriteAllLines($path, $lines)
        }

        'Build output'
        $global:LASTEXITCODE = $build['ExitCode'] ?? 0
    }
    elseif ($arguments[0] -eq 'test') {
        $test = $global:FakeDotnet.Tests[$name] ?? @{}
        $directory = $arguments[[Array]::IndexOf($arguments, '--results-directory') + 1]
        $trxName = @($arguments | Where-Object { $_ -like 'trx;LogFileName=*' })[0].Substring('trx;LogFileName='.Length)
        if ($test['Trx']) {
            [IO.File]::WriteAllText((Join-Path $directory $trxName), $test['Trx'])
        }

        $test['Output'] | Where-Object { $_ } | ForEach-Object { "$_".Replace('{root}', $global:FakeDotnet.Root) }
        $global:LASTEXITCODE = $test['ExitCode'] ?? 0
    }
}

function Reset-FakeDotnet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $global:FakeDotnet = @{
        Root   = $Root
        Calls  = [Collections.Generic.List[string]]::new()
        Builds = @{}
        Tests  = @{}
    }
}

function Remove-FakeDotnet {
    Remove-Item -LiteralPath function:global:dotnet -ErrorAction SilentlyContinue
    Remove-Variable -Name FakeDotnet -Scope Global -ErrorAction SilentlyContinue
}

function New-TestWarning {
    # A file-logger line for a warning in a repository file, attributed to -Project. {root} stands for the repository.
    param(
        [Parameter(Mandatory = $true)]
        [string]$File,

        [string]$Project = 'src/Abc.Plugins/Abc.Plugins.csproj',

        [string]$Code = 'CS0168',

        [string]$Message = "The variable 'e' is declared but never used",

        [string]$Location = '12,17'
    )

    "{root}/$File($Location): warning ${Code}: $Message [{root}/$Project]"
}

function New-TestTrx {
    param(
        [int]$Passed = 1,

        [string[]]$Failed = @(),

        [int]$Skipped = 0
    )

    $results = @(
        for ($i = 1; $i -le $Passed; $i++) { "<UnitTestResult testName=`"Passes$i`" outcome=`"Passed`" />" }
        foreach ($name in $Failed) { "<UnitTestResult testName=`"$name`" outcome=`"Failed`"><Output><ErrorInfo><Message>Expected True.`nSecond line.</Message></ErrorInfo></Output></UnitTestResult>" }
        for ($i = 1; $i -le $Skipped; $i++) { "<UnitTestResult testName=`"Skipped$i`" outcome=`"NotExecuted`" />" }
    )

    # Only the counters that every framework writes, to show that the error, timeout and aborted ones are optional.
    @"
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Results>
    $($results -join "`n    ")
  </Results>
  <ResultSummary outcome="Completed">
    <Counters total="$($Passed + $Failed.Count + $Skipped)" executed="$($Passed + $Failed.Count)" passed="$Passed" failed="$($Failed.Count)" />
  </ResultSummary>
</TestRun>
"@
}

function New-TestRepository {
    <#
    .SYNOPSIS
        Creates a git repository in TestDrive with one project of each kind that discovery recognises, and returns its
        path.
    #>
    $root = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('n').Substring(0, 8))

    $projects = [ordered]@{
        'src/Abc.Plugins/Abc.Plugins.csproj'                         = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Configurations>Debug;Release;UnitTest</Configurations>
  </PropertyGroup>
  <ItemGroup Condition="'$(Configuration)' == 'UnitTest'">
    <ProjectReference Include="..\Abc.SharedCode\Abc.SharedCode.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.60" PrivateAssets="all" />
  </ItemGroup>
</Project>
'@
        # An older, namespaced project file that declares its configurations only through conditions.
        'src/Abc.Workflows/Abc.Workflows.csproj'                     = @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
    <OutputPath>bin\Debug\</OutputPath>
  </PropertyGroup>
  <ItemGroup Condition="'$(Configuration)' == 'UnitTest'">
    <ProjectReference Include="..\Abc.SharedCode\Abc.SharedCode.csproj" />
  </ItemGroup>
  <ItemGroup>
    <Reference Include="Microsoft.Xrm.Sdk.Workflow, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" />
  </ItemGroup>
</Project>
'@
        'src/Abc.SharedCode/Abc.SharedCode.csproj'                   = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Configurations>UnitTest</Configurations>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.60" PrivateAssets="all" />
  </ItemGroup>
</Project>
'@
        'tests/Abc.UnitTests/Abc.UnitTests.csproj'                   = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Configurations>UnitTest</Configurations>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.60" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="18.0.0" />
  </ItemGroup>
</Project>
'@
        'tests/Abc.Reporting.Tests/Abc.Reporting.Tests.csproj'       = @'
<Project Sdk="MSTest.Sdk/3.6.4">
</Project>
'@
        'tests/Abc.AcceptanceTests/Abc.AcceptanceTests.csproj'       = @'
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="18.0.0" />
    <PackageReference Include="Reqnroll.MsTest" Version="2.0.0" />
    <PackageReference Include="Reqnroll" Version="2.0.0" />
  </ItemGroup>
</Project>
'@
        'tools/Abc.Reporting/Abc.Reporting.csproj'                   = @'
<Project Sdk="Microsoft.NET.Sdk">
</Project>
'@
        'src/Abc.Plugins/bin/Release/Abc.Copy.csproj'                = '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="Microsoft.Xrm.Sdk" /></ItemGroup></Project>'
        'node_modules/abc-package/Abc.Package.csproj'               = '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="Microsoft.Xrm.Sdk" /></ItemGroup></Project>'
    }

    foreach ($entry in $projects.GetEnumerator()) {
        $path = Join-Path $root $entry.Key
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, $entry.Value)
    }

    git -C $root init --quiet
    git -C $root add --all
    git -C $root -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit --quiet --message 'Initial commit'

    # Git writes its objects read-only, which stops Pester deleting TestDrive on Windows.
    Get-ChildItem -LiteralPath (Join-Path $root '.git') -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
    $root
}
