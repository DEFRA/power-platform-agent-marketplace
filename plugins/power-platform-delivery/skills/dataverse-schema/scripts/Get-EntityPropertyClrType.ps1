<#
.SYNOPSIS
    Reports the generated C# property name and exact CLR type for columns on an early-bound Dataverse table, read
    from the generated entity class instead of inferred from metadata.

.DESCRIPTION
    The model builder's property casing varies per column (abc_ReceivedOn, abc_receivedon and abc_ApplicantId can
    all occur), and the CLR type depends on the generated code: nullable wrapping, the virtual modifier, option set
    enum names and collection types. This script resolves both from the one unambiguous input, the column's
    logical name.

    It searches -ModelPath recursively for the file named <entity logical name>.cs. For each column it finds the
    [AttributeLogicalName("<name>")] annotation (with or without the Microsoft.Xrm.Sdk namespace and the
    Attribute suffix) and reads the property declaration on the line after it. That excludes the same-named
    constant in the nested Fields class, which has no such annotation.

    If the generated code is a single file, or is named differently, pass its path as -ModelPath and name the table
    with -EntityLogicalName anyway. A file path is read as it is.

.PARAMETER ModelPath
    The folder that holds the generated model (the Dataverse shared project's model folder), or the generated entity
    file itself. Discover it. Don't assume a location.

.PARAMETER EntityLogicalName
    The table's logical name, for example abc_inspection.

.PARAMETER AttributeName
    Column logical names to look up. The Web API lookup form (_abc_applicantid_value) is accepted. Omit to report
    every column in the file.

.EXAMPLE
    ./Get-EntityPropertyClrType.ps1 -ModelPath ./src/Abc.Dataverse/Model -EntityLogicalName abc_inspection -AttributeName abc_scheduledon, abc_outcome

.EXAMPLE
    ./Get-EntityFieldMetadata.ps1 -SolutionPath ./src/solutions -EntityLogicalName abc_inspection |
        ForEach-Object { ./Get-EntityPropertyClrType.ps1 -ModelPath ./src/Abc.Dataverse/Model -EntityLogicalName abc_inspection -AttributeName $_.LogicalName }
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)]
    [string]$ModelPath,

    [Parameter(Mandatory)]
    [string]$EntityLogicalName,

    [string[]]$AttributeName
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $ModelPath -PathType Leaf) {
    $entityFile = $ModelPath
}
elseif (Test-Path -LiteralPath $ModelPath -PathType Container) {
    $fileName = "$($EntityLogicalName.ToLowerInvariant()).cs"
    $entityFile = Get-ChildItem -LiteralPath $ModelPath -Recurse -Filter '*.cs' -File |
        Where-Object { $_.Name -ieq $fileName } |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $entityFile) {
        throw "Couldn't find '$fileName' under '$ModelPath'. If the model is out of date, ask the human to regenerate it (see the dataverse-schema skill)."
    }
}
else {
    throw "The model path '$ModelPath' doesn't exist."
}

$lines = Get-Content -LiteralPath $entityFile
$requested = @($AttributeName | Where-Object { $_ } | ForEach-Object { $_ -replace '^_(.*)_value$', '$1' })

# For example: public virtual abc_outcome? abc_Outcome  or  public System.Nullable<System.DateTime> abc_ReceivedOn
$propertyPattern = '^\s*public\s+(?:virtual\s+)?(?<type>.+?)\s+(?<name>\S+)\s*$'
$annotationPattern = 'AttributeLogicalName(?:Attribute)?\("(?<logicalName>[^"]+)"\)'

$results = for ($i = 0; $i -lt $lines.Count - 1; $i++) {
    if ($lines[$i] -notmatch $annotationPattern) {
        continue
    }

    $logicalName = $Matches.logicalName
    if ($requested.Count -gt 0 -and $logicalName -notin $requested) {
        continue
    }

    if ($lines[$i + 1] -notmatch $propertyPattern) {
        continue
    }

    [pscustomobject]@{
        LogicalName = $logicalName
        Property    = $Matches.name
        ClrType     = $Matches.type
    }
}

foreach ($name in $requested | Where-Object { $_ -notin @($results.LogicalName) }) {
    Write-Warning "Column not found in the generated class for '$EntityLogicalName': $name"
}

$results
