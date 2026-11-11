BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'Test-Change.ps1'
    $script:BaselineScript = Join-Path $ScriptsFolder 'New-WarningBaseline.ps1'
    $script:Inspection = New-TestWarning -File 'src/Abc.Application/Inspections/InspectionService.cs'
    $script:InspectionKey = "src/Abc.Application/Inspections/InspectionService.cs|CS0168|The variable 'e' is declared but never used"

    function Get-Call {
        param([string]$Verb)

        @($FakeDotnet.Calls | Where-Object { $_ -like "$Verb *" })
    }
}

AfterAll {
    Remove-FakeDotnet
}

Describe 'Test-Change.ps1' {
    BeforeEach {
        $script:Root = New-TestRepository
        $output = Join-Path $TestDrive ('output-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
        $script:Common = @{ RepositoryRoot = $Root; OutputDirectory = $output }
        Reset-FakeDotnet -Root $Root
        $FakeDotnet.Builds['Abc.Plugins'] = @{ Warnings = @($Inspection) }
        $FakeDotnet.Builds['Abc.UnitTests'] = @{ Warnings = @(
                New-TestWarning -File 'tests/Abc.UnitTests/CaseTests.cs' -Project 'tests/Abc.UnitTests/Abc.UnitTests.csproj' -Code 'MSTEST0017' -Message 'Assertion arguments are in the wrong order'
            )
        }
        $FakeDotnet.Tests['Abc.UnitTests'] = @{ Trx = New-TestTrx -Passed 3 }

        & $BaselineScript -Project 'src/Abc.Plugins/Abc.Plugins.csproj' -TestProject 'tests/Abc.UnitTests/Abc.UnitTests.csproj' @Common | Out-Null
        $FakeDotnet.Calls.Clear()
    }

    It 'passes when the warnings are unchanged and the tests pass' {
        $result = @(& $Script @Common)

        $LASTEXITCODE | Should -Be 0
        $result | Should -Contain 'BUILD     Abc.Plugins succeeded | Abc.UnitTests succeeded'
        $result | Should -Contain 'WARNINGS  baseline 2 -> current 2 | added 0 | removed 0'
        $result | Should -Contain 'TESTS     total 3 | passed 3 | failed 0 | skipped 0'
        $result[-2] | Should -BeExactly 'RESULT    PASS'
        $result[-1] | Should -BeLike 'DETAILS   *'
        Get-Call test | Should -BeLike '*Abc.UnitTests.csproj --configuration UnitTest *--no-build'
    }

    It 'fails on an added warning, including another occurrence of one in the baseline' {
        $FakeDotnet.Builds['Abc.Plugins'].Warnings += New-TestWarning -File 'src/Abc.Application/Inspections/InspectionService.cs' -Location '40,21'

        $result = @(& $Script @Common)

        $LASTEXITCODE | Should -Be 1
        $result | Should -Contain 'WARNINGS  baseline 2 -> current 3 | added 1 | removed 0'
        $result | Should -Contain "  +1 x $InspectionKey"
        $result | Should -Contain 'TESTS     total 3 | passed 3 | failed 0 | skipped 0'
        $result[-2] | Should -BeExactly 'RESULT    FAIL - 1 added warning(s)'
    }

    It 'passes when warnings are removed, and lists them by file' {
        $FakeDotnet.Builds['Abc.Plugins'].Warnings = @()

        $result = @(& $Script @Common)

        $LASTEXITCODE | Should -Be 0
        $result | Should -Contain 'WARNINGS  baseline 2 -> current 1 | added 0 | removed 1'
        $result | Should -Contain '  -1 x src/Abc.Application/Inspections/InspectionService.cs'
        $result[-2] | Should -BeExactly 'RESULT    PASS'
    }

    It 'fails a build error, shows it and runs no tests' {
        $FakeDotnet.Builds['Abc.Plugins'] = @{
            ExitCode = 1
            Errors   = @('{root}/src/Abc.Application/Cases/CaseService.cs(30,9): error CS0103: The name ''applicant'' does not exist in the current context [{root}/src/Abc.Plugins/Abc.Plugins.csproj]')
        }

        $result = @(& $Script @Common)

        $LASTEXITCODE | Should -Be 1
        $result | Should -Contain 'BUILD     Abc.Plugins FAILED | Abc.UnitTests succeeded'
        $result | Should -Contain "  src/Abc.Application/Cases/CaseService.cs|CS0103|The name 'applicant' does not exist in the current context"
        $result | Should -Contain 'TESTS     not run because a build failed; fix the build first'
        Get-Call test | Should -BeNullOrEmpty
        $result[-2] | Should -BeExactly 'RESULT    FAIL - Abc.Plugins build failed'
    }

    It 'fails failed tests and names them' {
        $FakeDotnet.Tests['Abc.UnitTests'] = @{ ExitCode = 1; Trx = New-TestTrx -Passed 2 -Failed 'Approve_WhenInspectionIsOverdue_Throws' }

        $result = @(& $Script @Common)

        $LASTEXITCODE | Should -Be 1
        $result | Should -Contain 'TESTS     total 3 | passed 2 | failed 1 | skipped 0'
        $result | Should -Contain '  FAILED Approve_WhenInspectionIsOverdue_Throws: Expected True.'
        $result[-2] | Should -BeExactly 'RESULT    FAIL - 1 failed test(s)'
    }

    It 'fails when a test project produces no results, and shows its compile errors' {
        $FakeDotnet.Tests['Abc.UnitTests'] = @{
            ExitCode = 1
            Output   = @('{root}/tests/Abc.UnitTests/CaseTests.cs(3,1): error CS0246: The type or namespace name ''Fact'' could not be found [{root}/tests/Abc.UnitTests/Abc.UnitTests.csproj]')
        }

        $result = @(& $Script -SkipBuild @Common)

        $LASTEXITCODE | Should -Be 1
        $result | Where-Object { $_ -like 'TESTS     Abc.UnitTests produced no results*' } | Should -Not -BeNullOrEmpty
        $result | Should -Contain "  tests/Abc.UnitTests/CaseTests.cs|CS0246|The type or namespace name 'Fact' could not be found"
        $result[-2] | Should -BeExactly 'RESULT    FAIL (build skipped) - no test results from Abc.UnitTests'
    }

    It 'lists every warning in files that match -PathFilter, new or not' {
        $result = @(& $Script -PathFilter 'src/Abc.Application/Inspections/*,tests/Abc.UnitTests/*' @Common)

        $LASTEXITCODE | Should -Be 0
        $result | Should -Contain 'IN SCOPE  2 warning(s) in files matching: src/Abc.Application/Inspections/*, tests/Abc.UnitTests/*'
        $result | Should -Contain "  1 x $InspectionKey"
        $result[-2] | Should -BeExactly 'RESULT    PASS'
    }

    It 'labels a run with -SkipBuild, and lets dotnet test build the projects' {
        $result = @(& $Script -SkipBuild @Common)

        $LASTEXITCODE | Should -Be 0
        Get-Call build | Should -BeNullOrEmpty
        Get-Call test | Should -Not -BeLike '*--no-build*'
        $result[-2] | Should -BeExactly 'RESULT    PASS (build skipped)'
    }

    It 'is INCOMPLETE when -PathFilter is used with -SkipBuild' {
        $result = @(& $Script -SkipBuild -PathFilter 'src/Abc.Application/Inspections/*' @Common)

        $LASTEXITCODE | Should -Be 2
        $result[-2] | Should -BeExactly 'RESULT    INCOMPLETE (build skipped) - -PathFilter was not checked because the build was skipped'
    }

    It 'passes -TestFilter to dotnet test and labels the run' {
        $result = @(& $Script -TestFilter 'FullyQualifiedName~Abc.UnitTests.Inspections' @Common)

        $LASTEXITCODE | Should -Be 0
        Get-Call test | Should -BeLike '*--no-build --filter FullyQualifiedName~Abc.UnitTests.Inspections'
        $result[-2] | Should -BeExactly 'RESULT    PASS (tests filtered)'
    }

    It 'is INCOMPLETE when no tests match -TestFilter' {
        $FakeDotnet.Tests['Abc.UnitTests'] = @{ Output = @('No test matches the given testcase filter `FullyQualifiedName~Abc.Missing` in Abc.UnitTests.dll') }

        $result = @(& $Script -TestFilter 'FullyQualifiedName~Abc.Missing' @Common)

        $LASTEXITCODE | Should -Be 2
        $result[-2] | Should -BeExactly "RESULT    INCOMPLETE (tests filtered) - no tests matched -TestFilter 'FullyQualifiedName~Abc.Missing'"
    }

    It 'is INCOMPLETE when both parts are skipped' {
        $result = @(& $Script -SkipBuild -SkipTests @Common)

        $LASTEXITCODE | Should -Be 2
        $FakeDotnet.Calls | Should -BeNullOrEmpty
        $result[-2] | Should -BeExactly 'RESULT    INCOMPLETE (build skipped; tests skipped) - nothing was verified'
    }

    It 'is INCOMPLETE, without building, when there is no baseline with that name' {
        $result = @(& $Script -BaselineName 'inspections' @Common)

        $LASTEXITCODE | Should -Be 2
        $FakeDotnet.Calls | Should -BeNullOrEmpty
        $result[-1] | Should -BeLike "RESULT    INCOMPLETE - no baseline named 'inspections' in *"
    }

    It 'is INCOMPLETE, without building, when a recorded project no longer exists' {
        Remove-Item -LiteralPath (Join-Path $Root 'src/Abc.Plugins/Abc.Plugins.csproj')

        $result = @(& $Script @Common)

        $LASTEXITCODE | Should -Be 2
        $FakeDotnet.Calls | Should -BeNullOrEmpty
        $result[-1] | Should -BeLike "RESULT    INCOMPLETE - baseline 'baseline' records projects that no longer exist: src/Abc.Plugins/Abc.Plugins.csproj.*"
    }

    It 'runs every recorded test project and adds up the results' {
        $FakeDotnet.Tests['Abc.Reporting.Tests'] = @{ Trx = New-TestTrx -Passed 1 -Skipped 1 }
        & $BaselineScript -Name 'two-test-projects' -Project 'src/Abc.Plugins/Abc.Plugins.csproj' -TestProject 'tests/Abc.UnitTests/Abc.UnitTests.csproj,tests/Abc.Reporting.Tests/Abc.Reporting.Tests.csproj' @Common | Out-Null
        $FakeDotnet.Calls.Clear()

        $result = @(& $Script -BaselineName 'two-test-projects' @Common)

        $LASTEXITCODE | Should -Be 0
        (Get-Call test).Count | Should -Be 2
        $result | Should -Contain 'TESTS     total 5 | passed 4 | failed 0 | skipped 1'
        $result[-2] | Should -BeExactly 'RESULT    PASS'
    }
}
