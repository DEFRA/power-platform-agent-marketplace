<#
.SYNOPSIS
    Lists the projects that the build verification should build: the Dataverse assembly heads and the unit test
    projects.

.DESCRIPTION
    Searches the repository for .csproj files, skipping bin, obj, node_modules, .git and .vs folders. It returns one
    object for each project that references the Dataverse SDK or is a test project, with the role and configuration
    the verification would use:

    - Head: references the Dataverse SDK, isn't a test project and declares a Release configuration. Built in Release.
    - SharedCode: references the Dataverse SDK but declares no Release configuration, such as a shared-code assembly
      that only the UnitTest build uses. Not suggested, because the builds that use it compile it.
    - UnitTests: a test project. Built in UnitTest when it declares that configuration, otherwise in Debug.
    - OtherTests: a test project that references Reqnroll, SpecFlow or Playwright. These need an environment, so they
      aren't suggested.

    It changes nothing. Confirm the suggested projects with the user, then pass them to New-WarningBaseline.ps1.

.PARAMETER RepositoryRoot
    The repository to search. Defaults to the git repository that contains the current location.

.EXAMPLE
    ./Find-VerificationProject.ps1

    Lists every candidate project with its role, configuration and the reason for it.

.EXAMPLE
    ./Find-VerificationProject.ps1 -RepositoryRoot ~/source/abc-case-management | Where-Object Suggested

    Lists only the suggested projects in another repository.
#>

#requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildVerification.psm1')

$root = Resolve-RepositoryRoot -RepositoryRoot $RepositoryRoot
Find-VerificationProject -RepositoryRoot $root
