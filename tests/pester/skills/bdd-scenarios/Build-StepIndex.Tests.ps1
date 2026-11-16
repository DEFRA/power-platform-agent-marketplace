BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'Build-StepIndex.ps1'

    $script:CaseSteps = @'
using Reqnroll;

namespace Abc.AcceptanceTests.Steps;

[Binding]
public class CaseSteps
{
    [Given(@"a case for applicant '(.*)'")]
    public void GivenACase(string name) { }

    [When("I record the inspection outcome as \"(.*)\"")]
    public void WhenIRecordTheOutcome(string outcome) { }

    [Then(@"the case shows ""(.*)""", Culture = "en-GB")]
    public void ThenTheCaseShows(string text) { }

    [Reqnroll.StepDefinition("there are (\\d+) inspections")]
    public void ThereAreInspections(int count) => this.Given("a step called from code");
}
'@
}

Describe 'Build-StepIndex.ps1' {
    Context 'a folder of step definitions' {
        BeforeAll {
            Write-TestFile 'suite/Steps/CaseSteps.cs' $CaseSteps
            Write-TestFile 'suite/Steps/Hooks.cs' '[Binding] public class Hooks { [BeforeScenario] public void Reset() { } }'
            Write-TestFile 'suite/Steps/README.md' '[Given("a step in a readme")]'
            Write-TestFile 'suite/obj/Debug/Generated.cs' '[Given("a generated step")]'
            Write-TestFile 'suite/Features/View cases.feature.cs' '[Given("a code-behind step")]'
            $suite = Join-Path $TestDrive 'suite'

            $script:Result = & $Script -StepsPath $suite -BasePath $suite -OutputPath (Join-Path $TestDrive 'out/steps.yaml')
        }

        It 'scans only the C# step definitions, skipping bin, obj and generated code' {
            $Result.FilesScanned | Should -Be 2
            $Result.BindingsFound | Should -Be 4
        }

        It 'lists each binding with its keyword, unescaped pattern and line' {
            $expected = @'
# Step bindings indexed by Build-StepIndex.ps1. Regenerate it rather than edit it.
bindings:
  - file: 'Steps/CaseSteps.cs'
    steps:
      - keyword: Given
        pattern: 'a case for applicant ''(.*)'''
        line: 8
      - keyword: When
        pattern: 'I record the inspection outcome as "(.*)"'
        line: 11
      - keyword: Then
        pattern: 'the case shows "(.*)"'
        line: 14
      - keyword: StepDefinition
        pattern: 'there are (\d+) inspections'
        line: 17
'@

            (Get-Content -LiteralPath $Result.Path) -join "`n" | Should -BeExactly ($expected -replace '\r\n', "`n")
        }
    }

    Context 'paths and output' {
        It 'makes paths relative to the root of the git repository by default' -Skip:(-not (Get-Command git -CommandType Application -ErrorAction Ignore)) {
            Write-TestFile 'repo/tests/Abc.AcceptanceTests/Steps/CaseSteps.cs' $CaseSteps
            git init -q (Join-Path $TestDrive 'repo')

            $result = & $Script -StepsPath (Join-Path $TestDrive 'repo/tests/Abc.AcceptanceTests') -OutputPath (Join-Path $TestDrive 'repo.yaml')

            Get-Content -LiteralPath $result.Path | Should -Contain "  - file: 'tests/Abc.AcceptanceTests/Steps/CaseSteps.cs'"
        }

        It 'makes paths relative to the scanned folder outside a repository' {
            Write-TestFile 'loose/Steps/CaseSteps.cs' $CaseSteps

            $result = Invoke-OutsideRepository -Ceiling (Join-Path $TestDrive 'loose') {
                & $Script -StepsPath (Join-Path $TestDrive 'loose/Steps') -OutputPath (Join-Path $TestDrive 'loose.yaml')
            }

            Get-Content -LiteralPath $result.Path | Should -Contain "  - file: 'CaseSteps.cs'"
        }

        It 'writes to a new file in the temporary folder by default' {
            Write-TestFile 'default/CaseSteps.cs' $CaseSteps

            $result = & $Script -StepsPath (Join-Path $TestDrive 'default')

            try {
                Split-Path -Parent $result.Path | Should -Be ([IO.Path]::GetTempPath().TrimEnd('\', '/'))
                Get-Content -LiteralPath $result.Path | Should -Contain '      - keyword: Given'
            }
            finally {
                Remove-Item -LiteralPath $result.Path -ErrorAction Ignore
            }
        }

        It 'writes an empty list when it finds no bindings' {
            New-Item -ItemType Directory -Path (Join-Path $TestDrive 'empty') | Out-Null

            $result = & $Script -StepsPath (Join-Path $TestDrive 'empty') -OutputPath (Join-Path $TestDrive 'empty.yaml')

            $result.BindingsFound | Should -Be 0
            Get-Content -LiteralPath $result.Path | Should -Contain 'bindings: []'
        }

        It 'fails when the steps folder is missing' {
            { & $Script -StepsPath (Join-Path $TestDrive 'missing') } | Should -Throw "*steps folder*doesn't exist*"
        }

        It 'documents itself for -?' {
            $help = Get-Help $Script

            $help.Synopsis | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
            foreach ($name in 'StepsPath', 'OutputPath', 'BasePath') {
                ($help.Parameters.Parameter | Where-Object Name -EQ $name).Description | Should -Not -BeNullOrEmpty
            }
        }
    }
}
