BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'Find-VerificationProject.ps1'
    $script:Root = New-TestRepository
    $script:Projects = @(& $Script -RepositoryRoot $Root)
}

AfterAll {
    Remove-FakeDotnet
}

Describe 'Find-VerificationProject.ps1' {
    It 'suggests each head in Release, whatever the project file style' -ForEach @(
        @{ Path = 'src/Abc.Plugins/Abc.Plugins.csproj' }
        @{ Path = 'src/Abc.Workflows/Abc.Workflows.csproj' }
    ) {
        $project = $Projects | Where-Object Path -EQ $Path

        $project.Role | Should -Be 'Head'
        $project.Configuration | Should -Be 'Release'
        $project.Suggested | Should -BeTrue
    }

    It 'suggests a unit test project in UnitTest when it declares that configuration' {
        $project = $Projects | Where-Object Path -EQ 'tests/Abc.UnitTests/Abc.UnitTests.csproj'

        $project.Role | Should -Be 'UnitTests'
        $project.Configuration | Should -Be 'UnitTest'
        $project.Suggested | Should -BeTrue
    }

    It 'suggests a unit test project in Debug when it has no UnitTest configuration' {
        $project = $Projects | Where-Object Path -EQ 'tests/Abc.Reporting.Tests/Abc.Reporting.Tests.csproj'

        $project.Role | Should -Be 'UnitTests'
        $project.Configuration | Should -Be 'Debug'
    }

    It 'lists the shared-code assembly without suggesting it' {
        $project = $Projects | Where-Object Path -EQ 'src/Abc.SharedCode/Abc.SharedCode.csproj'

        $project.Role | Should -Be 'SharedCode'
        $project.Suggested | Should -BeFalse
    }

    It 'lists tests that need an environment without suggesting them' {
        $project = $Projects | Where-Object Path -EQ 'tests/Abc.AcceptanceTests/Abc.AcceptanceTests.csproj'

        $project.Role | Should -Be 'OtherTests'
        $project.Suggested | Should -BeFalse
        $project.Reason | Should -BeLike '*Reqnroll*'
    }

    It 'ignores other projects and the bin, obj and node_modules folders' {
        $Projects.Path | Should -Be @(
            'src/Abc.Plugins/Abc.Plugins.csproj'
            'src/Abc.SharedCode/Abc.SharedCode.csproj'
            'src/Abc.Workflows/Abc.Workflows.csproj'
            'tests/Abc.AcceptanceTests/Abc.AcceptanceTests.csproj'
            'tests/Abc.Reporting.Tests/Abc.Reporting.Tests.csproj'
            'tests/Abc.UnitTests/Abc.UnitTests.csproj'
        )
    }

    It 'searches the git repository that contains the current location by default' {
        Push-Location (Join-Path $Root 'src/Abc.Plugins')
        try {
            $found = @(& $Script)
        }
        finally {
            Pop-Location
        }

        $found.Count | Should -Be $Projects.Count
    }

    It 'stops outside a git repository unless -RepositoryRoot is given' {
        $outside = Join-Path $TestDrive 'not-a-repository'
        New-Item -ItemType Directory -Force -Path $outside | Out-Null
        $ceiling = $env:GIT_CEILING_DIRECTORIES
        # Stops git from finding a repository above the test drive.
        $env:GIT_CEILING_DIRECTORIES = $TestDrive
        Push-Location $outside
        try {
            { & $Script } | Should -Throw '*not inside a git repository*'
        }
        finally {
            Pop-Location
            $env:GIT_CEILING_DIRECTORIES = $ceiling
        }
    }
}
