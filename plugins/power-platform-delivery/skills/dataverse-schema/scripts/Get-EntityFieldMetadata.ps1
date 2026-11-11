<#
.SYNOPSIS
    Reports the constraints on a Dataverse table's columns (type, required level, length, range, option values and
    create support) from the unpacked solution, so code and test data are written against verified values.

.DESCRIPTION
    Searches -SolutionPath recursively for the Entity.xml whose table logical name matches -EntityLogicalName, then
    reads each column:

    - Type, RequiredLevel, MaxLength, MinValue, MaxValue, Precision and ValidForCreateApi.
    - Format: for text, distinguishes single-line text from multi-line text; for date and time, date only from
      date and time.
    - Behavior (date and time columns only): UserLocal, DateOnly or TimeZoneIndependent. A date-only column must
      not be given a time of day.
    - OptionSet and OptionValues (value=label pairs in language 1033). Global option sets are read from the
      OptionSets folder next to the Entities folder.

    It doesn't report the generated C# property name or CLR type, because the model builder's casing and type
    choices can't be derived from the metadata. Use Get-EntityPropertyClrType.ps1 for those.

    It returns objects to the pipeline and writes a file only when -OutputPath is given. Don't commit that file.

.PARAMETER SolutionPath
    The folder to search for the unpacked solution. Pass the solution's own folder, or a parent folder that holds
    only the solutions you want searched.

.PARAMETER EntityLogicalName
    The table's logical name, for example abc_inspection.

.PARAMETER Field
    Column logical names to report on. The Web API lookup form (_abc_applicantid_value) is accepted. Omit to report
    every column.

.PARAMETER OutputPath
    A path to also write the results to as CSV.

.EXAMPLE
    ./Get-EntityFieldMetadata.ps1 -SolutionPath ./src/solutions/AbcCases -EntityLogicalName abc_inspection | Format-Table -AutoSize

.EXAMPLE
    ./Get-EntityFieldMetadata.ps1 -SolutionPath ./src/solutions -EntityLogicalName abc_inspection -Field abc_name, _abc_applicantid_value
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)]
    [string]$SolutionPath,

    [Parameter(Mandatory)]
    [string]$EntityLogicalName,

    [string[]]$Field,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SolutionPath -PathType Container)) {
    throw "The solution path '$SolutionPath' doesn't exist or isn't a folder."
}

$entityXml = $null
$entityXmlPath = $null
foreach ($candidate in Get-ChildItem -LiteralPath $SolutionPath -Recurse -Filter 'Entity.xml' -File) {
    [xml]$candidateXml = Get-Content -LiteralPath $candidate.FullName -Raw
    if ($candidateXml.Entity.EntityInfo.entity.Name -ieq $EntityLogicalName) {
        $entityXml = $candidateXml
        $entityXmlPath = $candidate.FullName
        break
    }
}

if (-not $entityXml) {
    throw "Couldn't find an Entity.xml for '$EntityLogicalName' under '$SolutionPath'."
}

# Global option sets sit in an OptionSets folder beside the Entities folder.
$optionSetsFolder = Join-Path (Split-Path (Split-Path $entityXmlPath -Parent) -Parent | Split-Path -Parent) 'OptionSets'
$optionSetCache = @{}

function Format-OptionValue {
    param($Option)

    $label = $Option.labels.label | Where-Object { $_.languagecode -eq '1033' } | Select-Object -First 1
    "$($Option.value)=$($label.description)"
}

function Get-GlobalOptionValue {
    param([string]$Name)

    if (-not $optionSetCache.ContainsKey($Name)) {
        $path = Join-Path $optionSetsFolder "$Name.xml"
        if (Test-Path -LiteralPath $path) {
            [xml]$optionSetXml = Get-Content -LiteralPath $path -Raw
            $optionSetCache[$Name] = (@($optionSetXml.optionset.options.option | ForEach-Object { Format-OptionValue $_ })) -join '; '
        }
        else {
            $optionSetCache[$Name] = $null
        }
    }

    $optionSetCache[$Name]
}

$attributes = @($entityXml.Entity.EntityInfo.entity.attributes.attribute)

if ($Field) {
    $requested = $Field | ForEach-Object { $_ -replace '^_(.*)_value$', '$1' }
    $attributes = @($attributes | Where-Object { $_.LogicalName -in $requested })

    foreach ($name in $requested | Where-Object { $_ -notin @($attributes.LogicalName) }) {
        Write-Warning "Column not found on '$EntityLogicalName': $name"
    }
}

$results = foreach ($attribute in $attributes) {
    $optionSetName = if ($attribute.OptionSetName) { $attribute.OptionSetName } elseif ($attribute.optionset.Name) { $attribute.optionset.Name } else { $null }

    $optionValues = if ($attribute.optionset.options.option) {
        (@($attribute.optionset.options.option | ForEach-Object { Format-OptionValue $_ })) -join '; '
    }
    elseif ($attribute.OptionSetName) {
        Get-GlobalOptionValue -Name $attribute.OptionSetName
    }

    [pscustomobject]@{
        LogicalName       = $attribute.LogicalName
        Type              = $attribute.Type
        RequiredLevel     = $attribute.RequiredLevel
        MaxLength         = $attribute.MaxLength
        MinValue          = $attribute.MinValue
        MaxValue          = $attribute.MaxValue
        Precision         = $attribute.Precision
        Format            = $attribute.Format
        Behavior          = switch ($attribute.Behavior) { '1' { 'UserLocal' } '2' { 'DateOnly' } '3' { 'TimeZoneIndependent' } default { $null } }
        ValidForCreateApi = $attribute.ValidForCreateApi
        OptionSet         = $optionSetName
        OptionValues      = $optionValues
    }
}

if ($OutputPath) {
    $results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
}

$results
