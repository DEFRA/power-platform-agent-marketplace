<#
.SYNOPSIS
    Builds a YAML index of the step bindings in a folder of C# step definitions.

.DESCRIPTION
    Searches StepsPath for .cs files, skipping bin and obj folders and generated .feature.cs files. Lists every Given,
    When, Then and StepDefinition attribute with its keyword, pattern and line, grouped by file. Files without a
    binding are left out.

    The index is written to OutputPath, which defaults to a new file in the temporary folder so that nothing is
    written inside the repository. File paths in the index are relative to BasePath when it's given, otherwise to the
    root of the git repository that contains StepsPath, otherwise to StepsPath.

.PARAMETER StepsPath
    The folder that contains the step definitions. It's searched recursively.

.PARAMETER OutputPath
    The YAML file to write. Defaults to a new file in the temporary folder.

.PARAMETER BasePath
    The folder that the file paths in the index are relative to.

.OUTPUTS
    An object with the Path of the index, the number of FilesScanned and the number of BindingsFound.

.EXAMPLE
    ./Build-StepIndex.ps1 -StepsPath ./tests/Abc.AcceptanceTests/Steps

    Indexes the step bindings and returns the path of the temporary file it wrote.

.EXAMPLE
    ./Build-StepIndex.ps1 -StepsPath ./tests/Abc.AcceptanceTests -BasePath ./tests -OutputPath ~/step-index.yaml

    Writes the index to step-index.yaml in the home folder, with paths relative to the tests folder.
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)]
    [string]$StepsPath,

    [string]$OutputPath = (Join-Path ([IO.Path]::GetTempPath()) "step-index-$([guid]::NewGuid().ToString('N')).yaml"),

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

$root = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($StepsPath)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "The steps folder '$StepsPath' doesn't exist."
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
    Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.cs' |
        Where-Object {
            $folders = @([IO.Path]::GetRelativePath($root, $_.FullName) -split '[\\/]' | Select-Object -SkipLast 1)
            $folders -notcontains 'bin' -and $folders -notcontains 'obj' -and
                -not $_.Name.EndsWith('.feature.cs', [StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object {
            [pscustomobject]@{
                FullName = $_.FullName
                Path     = ($prefix + [IO.Path]::GetRelativePath($base, $_.FullName)).Replace('\', '/')
            }
        } |
        Sort-Object Path
)

$bindingPattern = '[\[,]\s*(?:[\w.]+\.)?(?<keyword>Given|When|Then|StepDefinition)(?:Attribute)?\s*\(\s*' +
    '(?:@"(?<verbatim>(?:[^"]|"")*)"|"(?<regular>(?:[^"\\\r\n]|\\.)*)")'

$yaml = [Collections.Generic.List[string]]::new()
$yaml.Add('# Step bindings indexed by Build-StepIndex.ps1. Regenerate it rather than edit it.')
$bindingsFound = 0

foreach ($file in $files) {
    $content = [IO.File]::ReadAllText($file.FullName)
    $found = @([regex]::Matches($content, $bindingPattern))
    if ($found.Count -eq 0) { continue }

    $yaml.Add("  - file: $(ConvertTo-YamlString $file.Path)")
    $yaml.Add('    steps:')
    foreach ($match in $found) {
        $keyword = $match.Groups['keyword']
        $verbatim = $match.Groups['verbatim']
        $text = if ($verbatim.Success) { $verbatim.Value.Replace('""', '"') }
        else { [regex]::Replace($match.Groups['regular'].Value, '\\(["''\\])', '$1') }
        $line = ($content.Substring(0, $keyword.Index) -split "`n").Count

        $yaml.Add("      - keyword: $($keyword.Value)")
        $yaml.Add("        pattern: $(ConvertTo-YamlString $text)")
        $yaml.Add("        line: $line")
        $bindingsFound++
    }
}

$yaml.Insert(1, ($bindingsFound -eq 0 ? 'bindings: []' : 'bindings:'))

$outputFolder = Split-Path -Parent $output
if ($outputFolder -and -not (Test-Path -LiteralPath $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}
Set-Content -LiteralPath $output -Value $yaml -Encoding utf8NoBOM

[pscustomobject]@{
    Path          = $output
    FilesScanned  = $files.Count
    BindingsFound = $bindingsFound
}
