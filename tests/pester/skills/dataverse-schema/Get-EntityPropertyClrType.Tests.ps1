BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:Script = Join-Path $ScriptsFolder 'Get-EntityPropertyClrType.ps1'
    $script:Root = Join-Path $TestDrive 'repo'
    New-ModelFixture -Root $Root
    $script:ModelPath = Join-Path $Root 'Model'
}

Describe 'Get-EntityPropertyClrType.ps1' {
    It 'reports the property name and type exactly as generated' {
        $properties = @(& $Script -ModelPath $ModelPath -EntityLogicalName abc_inspection)

        $properties.Count | Should -Be 3
        ($properties | Where-Object LogicalName -EQ 'abc_name').Property | Should -Be 'abc_Name'
        ($properties | Where-Object LogicalName -EQ 'abc_name').ClrType | Should -Be 'string'
    }

    It 'keeps the per-column casing and nullable wrapping' {
        $property = & $Script -ModelPath $ModelPath -EntityLogicalName abc_inspection -AttributeName abc_receivedon

        $property.Property | Should -Be 'abc_receivedon'
        $property.ClrType | Should -Be 'System.Nullable<System.DateTime>'
    }

    It 'drops the virtual modifier and keeps the option set type' {
        $property = & $Script -ModelPath $ModelPath -EntityLogicalName abc_inspection -AttributeName abc_outcome

        $property.ClrType | Should -Be 'abc_inspection_outcome?'
    }

    It 'does not report the constants in the Fields class' {
        $properties = @(& $Script -ModelPath $ModelPath -EntityLogicalName abc_inspection -AttributeName abc_name)

        $properties.Count | Should -Be 1
    }

    It 'accepts the Web API lookup form of a column name' {
        $property = & $Script -ModelPath $ModelPath -EntityLogicalName abc_inspection -AttributeName _abc_name_value

        $property.Property | Should -Be 'abc_Name'
    }

    It 'accepts the path of the entity file itself' {
        $file = Join-Path $ModelPath 'Entities/abc_inspection.cs'

        @(& $Script -ModelPath $file -EntityLogicalName abc_inspection).Count | Should -Be 3
    }

    It 'warns about a column that is not in the class' {
        $null = & $Script -ModelPath $ModelPath -EntityLogicalName abc_inspection -AttributeName abc_missing -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -BeLike '*abc_missing*'
    }

    It 'tells the user to regenerate the model when the class is missing' {
        { & $Script -ModelPath $ModelPath -EntityLogicalName abc_missing } | Should -Throw '*regenerate*'
    }

    It 'fails when the model path does not exist' {
        { & $Script -ModelPath (Join-Path $TestDrive 'nowhere') -EntityLogicalName abc_inspection } | Should -Throw "*doesn't exist*"
    }

    It 'documents its parameters in -? help' {
        $help = Get-Help $Script -Full

        $help.Synopsis | Should -Not -BeNullOrEmpty
        foreach ($name in 'ModelPath', 'EntityLogicalName', 'AttributeName') {
            ($help.parameters.parameter | Where-Object name -EQ $name).description | Should -Not -BeNullOrEmpty
        }
    }
}
