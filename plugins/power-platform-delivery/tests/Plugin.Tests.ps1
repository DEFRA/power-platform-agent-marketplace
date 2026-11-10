BeforeAll {
    . (Join-Path $PSScriptRoot 'PluginLint.ps1')

    $script:PluginRoot = Split-Path -Parent $PSScriptRoot
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $script:PluginRoot)
    $script:Config = Get-LintConfig
    $script:Schemas = Join-Path $PSScriptRoot 'schemas'
}

Describe 'Manifests' {
    It 'plugin.json matches the plugin schema' {
        Test-Json -Path (Join-Path $PluginRoot 'plugin.json') -SchemaFile (Join-Path $Schemas 'plugin.schema.json') | Should -BeTrue
    }

    It 'plugin.json names the plugin folder' {
        (Get-Content (Join-Path $PluginRoot 'plugin.json') -Raw | ConvertFrom-Json).name | Should -Be (Split-Path -Leaf $PluginRoot)
    }

    It 'plugin.json points at agent and skill folders that exist' {
        $manifest = Get-Content (Join-Path $PluginRoot 'plugin.json') -Raw | ConvertFrom-Json
        Join-Path $PluginRoot $manifest.agents | Should -Exist
        Join-Path $PluginRoot $manifest.skills | Should -Exist
    }

    It 'marketplace.json matches the marketplace schema' {
        Test-Json -Path (Join-Path $RepoRoot '.github/plugin/marketplace.json') -SchemaFile (Join-Path $Schemas 'marketplace.schema.json') | Should -BeTrue
    }

    It 'marketplace.json lists this plugin with a source that exists' {
        $catalogue = Get-Content (Join-Path $RepoRoot '.github/plugin/marketplace.json') -Raw | ConvertFrom-Json
        $entry = $catalogue.plugins | Where-Object name -eq (Split-Path -Leaf $PluginRoot)
        $entry | Should -Not -BeNullOrEmpty
        Join-Path $RepoRoot $entry.source | Should -Exist
    }

    It 'marketplace.json and plugin.json agree on the description' {
        $catalogue = Get-Content (Join-Path $RepoRoot '.github/plugin/marketplace.json') -Raw | ConvertFrom-Json
        $manifest = Get-Content (Join-Path $PluginRoot 'plugin.json') -Raw | ConvertFrom-Json
        $catalogue.plugins[0].description | Should -Be $manifest.description
    }
}

Describe 'Agents' {
    It 'follow the authoring rules' {
        $violations = foreach ($file in Get-ChildItem (Join-Path $PluginRoot 'agents') -File -Filter '*.md') {
            Test-AgentFile -Path $file.FullName -Config $Config
        }
        @($violations) | Should -BeNullOrEmpty
    }
}

Describe 'Skills' {
    It 'follow the authoring rules' {
        $violations = foreach ($folder in Get-ChildItem (Join-Path $PluginRoot 'skills') -Directory) {
            Test-SkillFolder -Path $folder.FullName -Config $Config
        }
        @($violations) | Should -BeNullOrEmpty
    }
}

Describe 'Plugin links' {
    It 'every relative link resolves inside the plugin' {
        @(Test-MarkdownLinks -PluginRoot $PluginRoot) | Should -BeNullOrEmpty
    }
}

Describe 'Project configuration schema' {
    BeforeAll {
        $script:ConfigSchema = Join-Path $PluginRoot 'skills/power-platform-standards/assets/power-platform.schema.json'
        $script:ConfigExample = Join-Path $PluginRoot 'skills/power-platform-standards/assets/power-platform.example.json'
    }

    It 'the example validates against the schema' {
        Test-Json -Path $ConfigExample -SchemaFile $ConfigSchema | Should -BeTrue
    }

    It 'accepts a minimal config without Azure Boards' {
        Test-Json -Json '{ "schemaVersion": "1.0" }' -SchemaFile $ConfigSchema | Should -BeTrue
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a missing schemaVersion'; Json = '{ "azureBoards": { "organization": "o", "project": "p", "workItemTypes": { "epic": "e", "feature": "f", "story": "s", "task": "t" } } }' }
        @{ Case = 'an unknown top-level property'; Json = '{ "schemaVersion": "1.0", "solutions": [] }' }
        @{ Case = 'Azure Boards without a project'; Json = '{ "schemaVersion": "1.0", "azureBoards": { "organization": "o", "workItemTypes": { "epic": "e", "feature": "f", "story": "s", "task": "t" } } }' }
        @{ Case = 'incomplete work item types'; Json = '{ "schemaVersion": "1.0", "azureBoards": { "organization": "o", "project": "p", "workItemTypes": { "epic": "e" } } }' }
    ) {
        Test-Json -Json $Json -SchemaFile $ConfigSchema -ErrorAction SilentlyContinue | Should -BeFalse
    }
}
