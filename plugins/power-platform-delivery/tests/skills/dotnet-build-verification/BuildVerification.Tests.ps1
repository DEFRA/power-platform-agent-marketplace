BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    Import-Module (Join-Path $ScriptsFolder 'BuildVerification.psm1') -Force

    $script:Root = Join-Path $TestDrive 'repo'
    New-Item -ItemType Directory -Force -Path $Root | Out-Null
    $script:Separator = [IO.Path]::DirectorySeparatorChar
}

AfterAll {
    Remove-Module BuildVerification -ErrorAction SilentlyContinue
    Remove-FakeDotnet
}

Describe 'ConvertTo-DiagnosticKey' {
    BeforeAll {
        $script:Log = Join-Path $TestDrive 'warnings.log'
        $plugins = "$Root${Separator}src${Separator}Abc.Plugins${Separator}Abc.Plugins.csproj"
        $tests = "$Root${Separator}tests${Separator}Abc.UnitTests${Separator}Abc.UnitTests.csproj"
        [IO.File]::WriteAllLines($Log, [string[]]@(
                "  12>$Root${Separator}src${Separator}Abc.Application${Separator}Inspections${Separator}InspectionService.cs(12,17): warning CS0168: The variable 'e' is declared but never used [$plugins]"
                "$Root${Separator}tests${Separator}Abc.UnitTests${Separator}CaseTests.cs(40,9): warning MSTEST0017: Assertion arguments are in the wrong order [${tests}::TargetFramework=net48]"
                "$Root/src/Abc.Application/Cases/CaseService.cs(3,1): warning CS8019: Unnecessary using directive [$plugins]"
                'CSC : warning CS2008: No source files specified'
                'A line that is not a diagnostic'
                ''
            ))
    }

    It 'normalises each warning to file, code and message' {
        $keys = @(ConvertTo-DiagnosticKey -Path $Log -RepositoryRoot $Root -Severity warning -MatchedOnly)

        $keys | Should -Be @(
            "src/Abc.Application/Inspections/InspectionService.cs|CS0168|The variable 'e' is declared but never used"
            'tests/Abc.UnitTests/CaseTests.cs|MSTEST0017|Assertion arguments are in the wrong order'
            'src/Abc.Application/Cases/CaseService.cs|CS8019|Unnecessary using directive'
            'CSC|CS2008|No source files specified'
        )
    }

    It 'keeps lines it cannot parse unless -MatchedOnly is set' {
        $keys = @(ConvertTo-DiagnosticKey -Path $Log -RepositoryRoot $Root -Severity warning)

        $keys | Should -Contain '<unparsed>||A line that is not a diagnostic'
        $keys.Count | Should -Be 5
    }

    It 'with -Project returns only the warnings attributed to that project' {
        $keys = @(ConvertTo-DiagnosticKey -Path $Log -RepositoryRoot $Root -Severity warning -Project 'tests/Abc.UnitTests/Abc.UnitTests.csproj')

        $keys | Should -Be @('tests/Abc.UnitTests/CaseTests.cs|MSTEST0017|Assertion arguments are in the wrong order')
    }

    It 'reads errors with the same format' {
        $errorLog = Join-Path $TestDrive 'errors.log'
        [IO.File]::WriteAllLines($errorLog, [string[]]@("$Root/src/Abc.Application/Cases/CaseService.cs(8,5): error CS1002: ; expected [$Root/src/Abc.Plugins/Abc.Plugins.csproj]"))

        ConvertTo-DiagnosticKey -Path $errorLog -RepositoryRoot $Root -Severity error | Should -Be 'src/Abc.Application/Cases/CaseService.cs|CS1002|; expected'
    }

    It 'returns nothing for a missing log' {
        @(ConvertTo-DiagnosticKey -Path (Join-Path $TestDrive 'missing.log') -RepositoryRoot $Root -Severity warning) | Should -BeNullOrEmpty
    }
}

Describe 'Compare-DiagnosticCount' {
    It 'diffs the warnings as a multiset' {
        $baseline = Get-DiagnosticCount -Key @('a', 'a', 'b')
        $current = Get-DiagnosticCount -Key @('a', 'a', 'a', 'c')

        $diff = Compare-DiagnosticCount -Baseline $baseline -Current $current

        $diff.Added | ForEach-Object { "$($_.Count) x $($_.Key)" } | Should -Be @('1 x a', '1 x c')
        $diff.Removed | ForEach-Object { "$($_.Count) x $($_.Key)" } | Should -Be @('1 x b')
    }

    It 'treats keys that differ only in case as different warnings' {
        $diff = Compare-DiagnosticCount -Baseline (Get-DiagnosticCount -Key @('A')) -Current (Get-DiagnosticCount -Key @('a'))

        $diff.Added.Key | Should -Be 'a'
        $diff.Removed.Key | Should -Be 'A'
    }

    It 'handles empty sets' {
        $empty = Get-DiagnosticCount -Key @()

        $empty.Count | Should -Be 0
        $diff = Compare-DiagnosticCount -Baseline $empty -Current $empty
        $diff.Added | Should -BeNullOrEmpty
        $diff.Removed | Should -BeNullOrEmpty
    }
}

Describe 'Get-VerificationDirectory' {
    It 'creates the output directory when it is outside the repository' {
        $output = Join-Path $TestDrive 'output'

        Get-VerificationDirectory -RepositoryRoot $Root -OutputDirectory $output | Should -Be $output
        $output | Should -Exist
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'the repository root'; Relative = '' }
        @{ Case = 'a folder inside the repository'; Relative = 'out' }
    ) {
        { Get-VerificationDirectory -RepositoryRoot $Root -OutputDirectory (Join-Path $Root $Relative) } | Should -Throw '*outside the repository*'
    }

    It 'defaults to a folder for each checkout under the temporary directory' {
        $other = Join-Path $TestDrive 'other-repo'
        New-Item -ItemType Directory -Force -Path $other | Out-Null

        $first = Get-VerificationDirectory -RepositoryRoot $Root
        $second = Get-VerificationDirectory -RepositoryRoot $other
        try {
            $first | Should -BeLike (Join-Path ([IO.Path]::GetTempPath()) 'dotnet-build-verification*')
            Get-VerificationDirectory -RepositoryRoot $Root | Should -Be $first
            $second | Should -Not -Be $first
        }
        finally {
            Remove-Item -LiteralPath $first, $second -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Split-ListArgument' {
    It 'splits comma-separated values and drops blanks' {
        Split-ListArgument -Value @('a,b', ' c , ', 'd') | Should -Be @('a', 'b', 'c', 'd')
    }

    It 'returns nothing for no values' {
        @(Split-ListArgument -Value $null).Count | Should -Be 0
    }
}

Describe 'ConvertTo-RepositoryPath' {
    BeforeAll {
        $project = Join-Path $Root 'src/Abc.Plugins/Abc.Plugins.csproj'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $project) | Out-Null
        Set-Content -LiteralPath $project -Value '<Project />'
    }

    It 'accepts a <Case> path' -ForEach @(
        @{ Case = 'relative'; Path = 'src/Abc.Plugins/Abc.Plugins.csproj' }
        @{ Case = 'backslash'; Path = 'src\Abc.Plugins\Abc.Plugins.csproj' }
        @{ Case = 'absolute'; Path = 'ABSOLUTE' }
    ) {
        $value = if ($Path -eq 'ABSOLUTE') { $project } else { $Path }

        ConvertTo-RepositoryPath -RepositoryRoot $Root -Path $value | Should -Be 'src/Abc.Plugins/Abc.Plugins.csproj'
    }

    It 'rejects a project outside the repository' {
        $outside = Join-Path $TestDrive 'Abc.Outside.csproj'
        Set-Content -LiteralPath $outside -Value '<Project />'

        { ConvertTo-RepositoryPath -RepositoryRoot $Root -Path $outside } | Should -Throw '*inside the repository*'
    }

    It 'rejects a project that does not exist' {
        { ConvertTo-RepositoryPath -RepositoryRoot $Root -Path 'src/Abc.Missing/Abc.Missing.csproj' } | Should -Throw "*doesn't exist*"
    }
}

Describe 'Read-TestResult' {
    It 'totals the results and lists each failed test with the first line of its message' {
        $trx = Join-Path $TestDrive 'results.trx'
        [IO.File]::WriteAllText($trx, (New-TestTrx -Passed 3 -Failed 'CreatesInspection', 'RejectsApplicant' -Skipped 1))

        $result = Read-TestResult -Path $trx

        $result.Total | Should -Be 6
        $result.Passed | Should -Be 3
        $result.Failed | Should -Be 2
        $result.Skipped | Should -Be 1
        $result.FailedTests.Name | Should -Be @('CreatesInspection', 'RejectsApplicant')
        $result.FailedTests[0].Message | Should -Be 'Expected True.'
    }

    It 'counts an inconclusive test as failed, because it ran and did not pass' {
        $trx = Join-Path $TestDrive 'inconclusive.trx'
        [IO.File]::WriteAllText($trx, (New-TestTrx -Passed 2 -Inconclusive 'IsUnsure'))

        $result = Read-TestResult -Path $trx

        $result.Total | Should -Be 3
        $result.Failed | Should -Be 1
        $result.FailedTests.Name | Should -Be 'IsUnsure'
    }
}

Describe 'Get-ProjectInfo' {
    It 'takes configurations from == conditions and ignores != conditions' {
        $project = Join-Path $TestDrive 'conditions.csproj'
        @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup Condition="'$(Configuration)|$(Platform)' == 'Staging|AnyCPU'" />
  <ItemGroup Condition="'$(Configuration)' != 'UnitTest'" />
</Project>
'@ | Set-Content -LiteralPath $project

        $configurations = (Get-ProjectInfo -Path $project).Configurations

        $configurations | Should -Contain 'Staging'
        $configurations | Should -Not -Contain 'UnitTest'
    }
}

Describe 'Remove-OldVerificationRun' {
    It 'keeps the ten most recent run folders and nothing else is removed' {
        $directory = Join-Path $TestDrive 'runs'
        foreach ($i in 1..12) {
            New-Item -ItemType Directory -Force -Path (Join-Path $directory ('run-20250101-0000{0:00}-000-42' -f $i)) | Out-Null
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $directory 'baseline-logs') | Out-Null

        Remove-OldVerificationRun -Directory $directory

        $names = @(Get-ChildItem -LiteralPath $directory -Directory | Select-Object -ExpandProperty Name)
        $names | Should -Contain 'baseline-logs'
        $names | Should -Not -Contain 'run-20250101-000001-000-42'
        $names | Should -Not -Contain 'run-20250101-000002-000-42'
        @($names | Where-Object { $_ -like 'run-*' }).Count | Should -Be 10
    }
}

Describe 'Enter-VerificationLock' {
    It 'takes and releases the lock for a checkout' {
        $lock = Enter-VerificationLock -RepositoryRoot $Root
        $lock | Should -BeOfType [Threading.Mutex]
        Exit-VerificationLock -Lock $lock

        $again = Enter-VerificationLock -RepositoryRoot $Root -TimeoutMinutes 1
        Exit-VerificationLock -Lock $again
    }
}
