BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'Get-EntityFieldMetadata.ps1'
    $script:Root = Join-Path $TestDrive 'solutions'
    New-SolutionFixture -Root $Root
}

Describe 'Get-EntityFieldMetadata.ps1' {
    It 'reports every column of the table' {
        $columns = @(& $Script -SolutionPath $Root -EntityLogicalName abc_inspection)

        $columns.LogicalName | Should -Be @('abc_name', 'abc_scheduledon', 'abc_outcome', 'abc_kind', 'abc_applicantid')
    }

    It 'matches the table name without regard to case' {
        @(& $Script -SolutionPath $Root -EntityLogicalName ABC_Inspection).Count | Should -Be 5
    }

    It 'reports text constraints' {
        $column = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -Field abc_name

        $column.RequiredLevel | Should -Be 'required'
        $column.MaxLength | Should -Be '100'
        $column.Format | Should -Be 'text'
    }

    It 'names a date-only behaviour so no time of day is generated' {
        $column = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -Field abc_scheduledon

        $column.Behavior | Should -Be 'DateOnly'
    }

    It 'reads option values defined on the column' {
        $column = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -Field abc_outcome

        $column.OptionSet | Should -Be 'abc_inspection_outcome'
        $column.OptionValues | Should -Be '1=Passed; 2=Failed'
    }

    It 'reads option values from a global option set' {
        $column = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -Field abc_kind

        $column.OptionSet | Should -Be 'abc_inspectionkind'
        $column.OptionValues | Should -Be '10=Routine; 20=Follow-up'
    }

    It 'accepts the Web API lookup form of a column name' {
        $column = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -Field _abc_applicantid_value

        $column.LogicalName | Should -Be 'abc_applicantid'
        $column.Type | Should -Be 'lookup'
    }

    It 'warns about a column that does not exist' {
        $null = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -Field abc_missing -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -BeLike '*abc_missing*'
    }

    It 'writes a CSV only when asked' {
        $path = Join-Path $TestDrive 'columns.csv'

        $null = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection
        $path | Should -Not -Exist

        $null = & $Script -SolutionPath $Root -EntityLogicalName abc_inspection -OutputPath $path
        @(Import-Csv $path).Count | Should -Be 5
    }

    It 'fails when the table is not in the solution' {
        { & $Script -SolutionPath $Root -EntityLogicalName abc_missing } | Should -Throw "*abc_missing*"
    }

    It 'fails when the solution path does not exist' {
        { & $Script -SolutionPath (Join-Path $TestDrive 'nowhere') -EntityLogicalName abc_inspection } | Should -Throw "*doesn't exist*"
    }

    It 'documents its parameters in -? help' {
        $help = Get-Help $Script -Full

        $help.Synopsis | Should -Not -BeNullOrEmpty
        foreach ($name in 'SolutionPath', 'EntityLogicalName', 'Field', 'OutputPath') {
            ($help.parameters.parameter | Where-Object name -EQ $name).description | Should -Not -BeNullOrEmpty
        }
    }
}
