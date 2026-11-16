# Shared set-up for the bdd-scenarios tests. Pester runs only *.Tests.ps1 files, so this file isn't a test.

. (Join-Path $PSScriptRoot '../../TestPaths.ps1')

$script:ScriptsFolder = Join-Path $script:PluginRoot 'skills/bdd-scenarios/scripts'

function Write-TestFile {
    param([string]$Path, [string[]]$Lines)

    $full = Join-Path $TestDrive $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full) | Out-Null
    Set-Content -LiteralPath $full -Value $Lines
}

# Stops git searching above $Ceiling while the script block runs, so a repository around the temporary folder can't
# change the result.
function Invoke-OutsideRepository {
    param([string]$Ceiling, [scriptblock]$ScriptBlock)

    $previous = $env:GIT_CEILING_DIRECTORIES
    try {
        $env:GIT_CEILING_DIRECTORIES = $Ceiling
        & $ScriptBlock
    }
    finally {
        $env:GIT_CEILING_DIRECTORIES = $previous
    }
}
