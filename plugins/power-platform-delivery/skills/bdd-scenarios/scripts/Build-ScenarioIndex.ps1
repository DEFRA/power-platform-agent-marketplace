<#
.SYNOPSIS
    Builds a YAML index of the scenarios in a folder of Gherkin feature files.

.DESCRIPTION
    Searches FeaturesPath for .feature files, skipping bin and obj folders. Lists each feature with its tags, and
    each Scenario, Scenario Outline, Scenario Template and Example with its name, line and tags. Text inside doc
    strings is ignored, and tags on an Examples table aren't given to the next scenario.

    The index is written to OutputPath, which defaults to a new file in the temporary folder so that nothing is
    written inside the repository. File paths in the index are relative to BasePath when it's given, otherwise to the
    root of the git repository that contains FeaturesPath, otherwise to FeaturesPath.

.PARAMETER FeaturesPath
    The folder that contains the feature files. It's searched recursively.

.PARAMETER OutputPath
    The YAML file to write. Defaults to a new file in the temporary folder.

.PARAMETER BasePath
    The folder that the file paths in the index are relative to.

.OUTPUTS
    An object with the Path of the index, the number of FilesScanned and the number of ScenariosFound.

.EXAMPLE
    ./Build-ScenarioIndex.ps1 -FeaturesPath ./tests/Abc.AcceptanceTests/Features

    Indexes the scenarios and returns the path of the temporary file it wrote.

.EXAMPLE
    ./Build-ScenarioIndex.ps1 -FeaturesPath ./tests/Abc.AcceptanceTests -BasePath ./tests -OutputPath ~/scenarios.yaml

    Writes the index to scenarios.yaml in the home folder, with paths relative to the tests folder.
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)]
    [string]$FeaturesPath,

    [string]$OutputPath = (Join-Path ([IO.Path]::GetTempPath()) "scenario-index-$([guid]::NewGuid().ToString('N')).yaml"),

    [string]$BasePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitPrefix {
    param([string]$Folder)

    if (-not (Get-Command git -CommandType Application -ErrorAction Ignore)) { return $null }
    # Only the exit code matters: stderr from git outside a repository mustn't stop the script.
    $ErrorActionPreference = 'Continue'
    $prefix = & git -C $Folder rev-parse --show-prefix 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    "$prefix".Trim()
}

function ConvertTo-YamlString {
    param([string]$Value)

    "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-YamlList {
    param([string[]]$Values)

    '[' + (@($Values | ForEach-Object { ConvertTo-YamlString $_ }) -join ', ') + ']'
}

$root = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($FeaturesPath)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "The features folder '$FeaturesPath' doesn't exist."
}
$output = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)

if ($BasePath) {
    $base = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($BasePath)
    $prefix = ''
}
else {
    # Git reports the scanned folder's place in the repository, so this works whatever form the scanned path takes.
    $base = $root
    $prefix = (Get-GitPrefix -Folder $root) ?? ''
}

$files = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.feature' |
        Where-Object {
            $folders = @([IO.Path]::GetRelativePath($root, $_.FullName) -split '[\\/]' | Select-Object -SkipLast 1)
            $folders -notcontains 'bin' -and $folders -notcontains 'obj'
        } |
        ForEach-Object {
            [pscustomobject]@{
                FullName = $_.FullName
                Path     = ($prefix + [IO.Path]::GetRelativePath($base, $_.FullName)).Replace('\', '/')
            }
        } |
        Sort-Object Path
)

$yaml = [Collections.Generic.List[string]]::new()
$yaml.Add('# Scenarios indexed by Build-ScenarioIndex.ps1. Regenerate it rather than edit it.')
$yaml.Add($files.Count -eq 0 ? 'features: []' : 'features:')
$scenariosFound = 0

foreach ($file in $files) {
    $feature = ''
    $featureTags = @()
    $scenarios = [Collections.Generic.List[object]]::new()
    $pendingTags = [Collections.Generic.List[string]]::new()
    $docStringDelimiter = $null
    $lines = [IO.File]::ReadAllLines($file.FullName)

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index].Trim()

        if ($docStringDelimiter) {
            if ($line.StartsWith($docStringDelimiter)) { $docStringDelimiter = $null }
            continue
        }
        if ($line.StartsWith('"""') -or $line.StartsWith('```')) {
            $docStringDelimiter = $line.Substring(0, 3)
            continue
        }
        # Comments and blank lines can sit between tags and the scenario they belong to.
        if ($line -eq '' -or $line.StartsWith('#')) { continue }

        if ($line.StartsWith('@')) {
            foreach ($token in $line -split '\s+') {
                if ($token.StartsWith('#')) { break }
                $pendingTags.Add($token)
            }
            continue
        }

        if ($line -cmatch '^Feature:\s*(?<name>.*)$') {
            $feature = $Matches['name'].Trim()
            $featureTags = $pendingTags.ToArray()
        }
        elseif ($line -cmatch '^(?:Scenario Outline|Scenario Template|Scenario|Example):\s*(?<name>.*)$') {
            $scenarios.Add([pscustomobject]@{
                    Name = $Matches['name'].Trim()
                    Line = $index + 1
                    Tags = $pendingTags.ToArray()
                })
        }
        $pendingTags.Clear()
    }

    $yaml.Add("  - file: $(ConvertTo-YamlString $file.Path)")
    $yaml.Add("    feature: $(ConvertTo-YamlString $feature)")
    $yaml.Add("    tags: $(ConvertTo-YamlList $featureTags)")
    $yaml.Add($scenarios.Count -eq 0 ? '    scenarios: []' : '    scenarios:')
    foreach ($scenario in $scenarios) {
        $yaml.Add("      - name: $(ConvertTo-YamlString $scenario.Name)")
        $yaml.Add("        line: $($scenario.Line)")
        $yaml.Add("        tags: $(ConvertTo-YamlList $scenario.Tags)")
    }
    $scenariosFound += $scenarios.Count
}

$outputFolder = Split-Path -Parent $output
if ($outputFolder -and -not (Test-Path -LiteralPath $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}
Set-Content -LiteralPath $output -Value $yaml -Encoding utf8NoBOM

[pscustomobject]@{
    Path           = $output
    FilesScanned   = $files.Count
    ScenariosFound = $scenariosFound
}
