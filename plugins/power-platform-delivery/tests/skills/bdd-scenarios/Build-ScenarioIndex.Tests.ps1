BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'Build-ScenarioIndex.ps1'

    $script:ViewCases = @'
# language: en
@cases
Feature: View cases

Background:
    Given I am logged in to the 'Case Management' app as 'Inspector'

@issue:1234 @smoke # The main view
# The active cases view is the default
Scenario: An inspector views the active cases
    When I open the active cases view
    Then the view shows the columns
        | Case number | Applicant | Status |

@issue:1235
Scenario Outline: An inspector filters the cases by status
    When I filter the cases by '<status>'
    Then only cases with the status '<status>' are shown

    @fast
    Examples:
        | status |
        | Open   |
        | Closed |

Scenario: An inspector sees no closed cases in the active view
    When I open the active cases view
    Then no closed cases are shown
'@

    $script:AddNote = @'
Feature: Add a case note

Example: An inspector's note keeps its formatting
    Given I am logged in to the 'Case Management' app as 'Inspector'
    And a case is assigned to me
    When I add a note to the case
        """
        Scenario: text that looks like Gherkin
        @not-a-tag
        """
    Then the note is shown as written
'@
}

Describe 'Build-ScenarioIndex.ps1' {
    Context 'a folder of feature files' {
        BeforeAll {
            Write-TestFile 'suite/Cases/View cases.feature' $ViewCases
            Write-TestFile 'suite/Cases/Add a case note.feature' $AddNote
            Write-TestFile 'suite/Inspections/Record an inspection outcome.feature' @(
                'Feature: Record an inspection outcome'
                '    Inspectors record the outcome of each inspection they carry out.'
            )
            Write-TestFile 'suite/bin/Debug/Cases/View cases.feature' $ViewCases
            $suite = Join-Path $TestDrive 'suite'

            $script:Result = & $Script -FeaturesPath $suite -BasePath $suite -OutputPath (Join-Path $TestDrive 'out/scenarios.yaml')
        }

        It 'scans the feature files, skipping bin and obj' {
            $Result.FilesScanned | Should -Be 3
            $Result.ScenariosFound | Should -Be 4
        }

        It 'lists each feature and scenario with its tags and line, ignoring doc strings and Examples tags' {
            $expected = @'
# Scenarios indexed by Build-ScenarioIndex.ps1. Regenerate it rather than edit it.
features:
  - file: 'Cases/Add a case note.feature'
    feature: 'Add a case note'
    tags: []
    scenarios:
      - name: 'An inspector''s note keeps its formatting'
        line: 3
        tags: []
  - file: 'Cases/View cases.feature'
    feature: 'View cases'
    tags: ['@cases']
    scenarios:
      - name: 'An inspector views the active cases'
        line: 10
        tags: ['@issue:1234', '@smoke']
      - name: 'An inspector filters the cases by status'
        line: 16
        tags: ['@issue:1235']
      - name: 'An inspector sees no closed cases in the active view'
        line: 26
        tags: []
  - file: 'Inspections/Record an inspection outcome.feature'
    feature: 'Record an inspection outcome'
    tags: []
    scenarios: []
'@

            (Get-Content -LiteralPath $Result.Path) -join "`n" | Should -BeExactly ($expected -replace '\r\n', "`n")
        }
    }

    Context 'paths and output' {
        It 'makes paths relative to the root of the git repository by default' -Skip:(-not (Get-Command git -CommandType Application -ErrorAction Ignore)) {
            Write-TestFile 'repo/tests/Abc.AcceptanceTests/Features/View cases.feature' $ViewCases
            git init -q (Join-Path $TestDrive 'repo')

            $result = & $Script -FeaturesPath (Join-Path $TestDrive 'repo/tests/Abc.AcceptanceTests') -OutputPath (Join-Path $TestDrive 'repo.yaml')

            Get-Content -LiteralPath $result.Path | Should -Contain "  - file: 'tests/Abc.AcceptanceTests/Features/View cases.feature'"
        }

        It 'makes paths relative to the scanned folder outside a repository' {
            Write-TestFile 'loose/Features/View cases.feature' $ViewCases

            $result = Invoke-OutsideRepository -Ceiling (Join-Path $TestDrive 'loose') {
                & $Script -FeaturesPath (Join-Path $TestDrive 'loose/Features') -OutputPath (Join-Path $TestDrive 'loose.yaml')
            }

            Get-Content -LiteralPath $result.Path | Should -Contain "  - file: 'View cases.feature'"
        }

        It 'writes to a new file in the temporary folder by default' {
            Write-TestFile 'default/View cases.feature' $ViewCases

            $result = & $Script -FeaturesPath (Join-Path $TestDrive 'default')

            try {
                Split-Path -Parent $result.Path | Should -Be ([IO.Path]::GetTempPath().TrimEnd('\', '/'))
                Get-Content -LiteralPath $result.Path | Should -Contain "    feature: 'View cases'"
            }
            finally {
                Remove-Item -LiteralPath $result.Path -ErrorAction Ignore
            }
        }

        It 'writes an empty list when it finds no feature files' {
            New-Item -ItemType Directory -Path (Join-Path $TestDrive 'empty') | Out-Null

            $result = & $Script -FeaturesPath (Join-Path $TestDrive 'empty') -OutputPath (Join-Path $TestDrive 'empty.yaml')

            $result.ScenariosFound | Should -Be 0
            Get-Content -LiteralPath $result.Path | Should -Contain 'features: []'
        }

        It 'fails when the features folder is missing' {
            { & $Script -FeaturesPath (Join-Path $TestDrive 'missing') } | Should -Throw "*features folder*doesn't exist*"
        }

        It 'documents itself for -?' {
            $help = Get-Help $Script

            $help.Synopsis | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
            foreach ($name in 'FeaturesPath', 'OutputPath', 'BasePath') {
                ($help.Parameters.Parameter | Where-Object Name -EQ $name).Description | Should -Not -BeNullOrEmpty
            }
        }
    }
}
