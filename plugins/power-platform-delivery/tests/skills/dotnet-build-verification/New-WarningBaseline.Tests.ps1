BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'New-WarningBaseline.ps1'
    $script:Heads = 'src/Abc.Plugins/Abc.Plugins.csproj,src/Abc.Workflows/Abc.Workflows.csproj'
    $script:UnitTests = 'tests/Abc.UnitTests/Abc.UnitTests.csproj'
}

AfterAll {
    Remove-FakeDotnet
}

Describe 'New-WarningBaseline.ps1' {
    BeforeEach {
        $script:Root = New-TestRepository
        $script:Output = Join-Path $TestDrive ('output-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
        Reset-FakeDotnet -Root $Root
        $FakeDotnet.Builds['Abc.Plugins'] = @{ Warnings = @(
                New-TestWarning -File 'src/Abc.Application/Inspections/InspectionService.cs'
                New-TestWarning -File 'src/Abc.Application/Cases/CaseService.cs' -Code 'CS8019' -Message 'Unnecessary using directive'
            )
        }
        $FakeDotnet.Builds['Abc.UnitTests'] = @{ Warnings = @(
                # The test build repeats the warnings of the heads it references; only its own are recorded.
                New-TestWarning -File 'src/Abc.Application/Inspections/InspectionService.cs'
                New-TestWarning -File 'tests/Abc.UnitTests/CaseTests.cs' -Project 'tests/Abc.UnitTests/Abc.UnitTests.csproj' -Code 'MSTEST0017' -Message 'Assertion arguments are in the wrong order'
            )
        }
    }

    It 'saves the warnings, sorted, and the projects it built' {
        $result = @(& $Script -Project $Heads -TestProject $UnitTests -RepositoryRoot $Root -OutputDirectory $Output)

        $LASTEXITCODE | Should -Be 0
        $result | Should -Contain "SAVED     $(Join-Path $Output 'baseline.warnings.txt')"
        Get-Content -LiteralPath (Join-Path $Output 'baseline.warnings.txt') | Should -Be @(
            "src/Abc.Application/Cases/CaseService.cs|CS8019|Unnecessary using directive"
            "src/Abc.Application/Inspections/InspectionService.cs|CS0168|The variable 'e' is declared but never used"
            'tests/Abc.UnitTests/CaseTests.cs|MSTEST0017|Assertion arguments are in the wrong order'
        )

        $metadata = Get-Content -LiteralPath (Join-Path $Output 'baseline.json') -Raw | ConvertFrom-Json
        $metadata.warnings | Should -Be 3
        $metadata.sdk | Should -Be '10.0.100'
        $metadata.commit | Should -Be (git -C $Root rev-parse --short HEAD)
        $metadata.uncommittedChanges | Should -BeFalse
        $metadata.projects | ForEach-Object { '{0}|{1}|{2}' -f $_.path, $_.configuration, $_.role } | Should -Be @(
            'src/Abc.Plugins/Abc.Plugins.csproj|Release|Head'
            'src/Abc.Workflows/Abc.Workflows.csproj|Release|Head'
            'tests/Abc.UnitTests/Abc.UnitTests.csproj|UnitTest|UnitTests'
        )
    }

    It 'builds each project in its configuration with the verification flags' {
        & $Script -Project $Heads -TestProject $UnitTests -TestConfiguration Debug -RepositoryRoot $Root -OutputDirectory $Output | Out-Null

        $builds = @($FakeDotnet.Calls | Where-Object { $_ -like 'build *' })
        $builds.Count | Should -Be 3
        $builds[0] | Should -BeLike '*Abc.Plugins.csproj --configuration Release -v q -nologo --no-incremental*'
        $builds[2] | Should -BeLike '*Abc.UnitTests.csproj --configuration Debug *'
    }

    It 'accepts a list passed as separate values' {
        & $Script -Project 'src/Abc.Plugins/Abc.Plugins.csproj', 'src/Abc.Workflows/Abc.Workflows.csproj' -TestProject $UnitTests -RepositoryRoot $Root -OutputDirectory $Output | Out-Null

        (Get-Content -LiteralPath (Join-Path $Output 'baseline.json') -Raw | ConvertFrom-Json).projects.Count | Should -Be 3
    }

    It 'saves nothing when a build fails, and removes an earlier baseline with the same name' {
        & $Script -Project $Heads -TestProject $UnitTests -RepositoryRoot $Root -OutputDirectory $Output | Out-Null
        $FakeDotnet.Builds['Abc.Workflows'] = @{
            ExitCode = 1
            Errors   = @('{root}/src/Abc.Workflows/CopyField.cs(8,5): error CS1002: ; expected [{root}/src/Abc.Workflows/Abc.Workflows.csproj]')
        }

        $result = @(& $Script -Project $Heads -TestProject $UnitTests -RepositoryRoot $Root -OutputDirectory $Output)

        $LASTEXITCODE | Should -Be 1
        $result | Should -Contain '  src/Abc.Workflows/CopyField.cs|CS1002|; expected'
        $result[-1] | Should -BeLike 'RESULT    FAIL - baseline not saved*'
        Join-Path $Output 'baseline.warnings.txt' | Should -Not -Exist
        Join-Path $Output 'baseline.json' | Should -Not -Exist
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a project that does not exist'; Project = 'src/Abc.Missing/Abc.Missing.csproj'; Message = "*doesn't exist*" }
        @{ Case = 'a project outside the repository'; Project = 'OUTSIDE'; Message = '*inside the repository*' }
    ) {
        if ($Project -eq 'OUTSIDE') {
            $Project = Join-Path $TestDrive 'Abc.Outside.csproj'
            Set-Content -LiteralPath $Project -Value '<Project />'
        }

        { & $Script -Project $Project -TestProject $UnitTests -RepositoryRoot $Root -OutputDirectory $Output } | Should -Throw $Message
        $FakeDotnet.Calls | Should -BeNullOrEmpty
    }

    It 'rejects an output directory inside the repository' {
        { & $Script -Project $Heads -TestProject $UnitTests -RepositoryRoot $Root -OutputDirectory (Join-Path $Root 'verification') } | Should -Throw '*outside the repository*'
    }
}
