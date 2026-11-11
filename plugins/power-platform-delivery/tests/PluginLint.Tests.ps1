BeforeAll {
    . (Join-Path $PSScriptRoot 'PluginLint.ps1')

    $script:Config = Get-LintConfig
    $script:Config.allowedModels = @('small-model')

    function Write-Fixture {
        param([string]$Path, [string[]]$Lines)
        $full = Join-Path $TestDrive $Path
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full) | Out-Null
        Set-Content -LiteralPath $full -Value $Lines
        $full
    }

    function New-Agent {
        param([string]$Id = 'sample', [string[]]$Frontmatter, [int]$BodyLines = 3)
        if (-not $PSBoundParameters.ContainsKey('Frontmatter')) {
            $Frontmatter = @("name: $Id", 'description: Reviews cases for an applicant.', 'tools: [read, search]')
        }
        $lines = @('---') + $Frontmatter + @('---') + (1..$BodyLines | ForEach-Object { "Line $_" })
        Write-Fixture -Path "agents-$([guid]::NewGuid())/$Id.agent.md" -Lines $lines
    }

    function New-Skill {
        param([string]$Folder = 'sample-skill', [string[]]$Frontmatter, [int]$BodyLines = 3)
        if (-not $PSBoundParameters.ContainsKey('Frontmatter')) {
            $Frontmatter = @("name: $Folder", 'description: Explains how to record an inspection.')
        }
        $root = Join-Path $TestDrive "skills-$([guid]::NewGuid())/$Folder"
        $lines = @('---') + $Frontmatter + @('---') + (1..$BodyLines | ForEach-Object { "Line $_" })
        Write-Fixture -Path ((Join-Path $root 'SKILL.md').Substring($TestDrive.Length + 1)) -Lines $lines | Out-Null
        $root
    }
}

Describe 'Read-Frontmatter' {
    It 'reads scalars, quoted values, flow lists and block lists' {
        $path = Write-Fixture 'fm/a.md' @(
            '---', 'name: sample', "description: 'It''s quoted: yes'", 'tools: [read, "search"]',
            'keywords:', '  - one', '  - two', '---', 'Body')
        $front = Read-Frontmatter -Path $path

        $front.Found | Should -BeTrue
        $front.Fields['name'] | Should -Be 'sample'
        $front.Fields['description'] | Should -Be "It's quoted: yes"
        $front.Quoted | Should -Contain 'description'
        $front.Fields['tools'] | Should -Be @('read', 'search')
        $front.Fields['keywords'] | Should -Be @('one', 'two')
    }

    It 'folds block scalars' {
        $path = Write-Fixture 'fm/b.md' @('---', 'description: >', '  First part', '  second part', 'name: x', '---', 'Body')
        $front = Read-Frontmatter -Path $path

        $front.Fields['description'] | Should -Be 'First part second part'
        $front.Fields['name'] | Should -Be 'x'
    }

    It 'reads a map of scalars and an unindented block list' {
        $path = Write-Fixture 'fm/f.md' @(
            '---', 'name: x', 'metadata:', '  author: defra', "  version: '1.0'", 'tools:', '- read', '- search', 'license: OGL', '---', 'Body')
        $front = Read-Frontmatter -Path $path

        $front.Error | Should -BeNullOrEmpty
        $front.Fields['metadata']['author'] | Should -Be 'defra'
        $front.Fields['metadata']['version'] | Should -Be '1.0'
        $front.Fields['tools'] | Should -Be @('read', 'search')
        $front.Fields['license'] | Should -Be 'OGL'
    }

    It 'reports every line it cannot parse' {
        $path = Write-Fixture 'fm/g.md' @('---', 'name: x', '  stray: one', '!bad', '---', 'Body')
        $front = Read-Frontmatter -Path $path

        $front.Error | Should -Match 'line 3'
        $front.Error | Should -Match 'line 4'
    }

    It 'counts body lines without leading or trailing blanks' {
        $path = Write-Fixture 'fm/c.md' @('---', 'name: x', '---', '', 'One', '', 'Two', '', '')
        (Read-Frontmatter -Path $path).BodyLineCount | Should -Be 3
    }

    It 'reports a file with no frontmatter' {
        $path = Write-Fixture 'fm/d.md' @('# Title', 'Text')
        $front = Read-Frontmatter -Path $path

        $front.Found | Should -BeFalse
        $front.BodyLineCount | Should -Be 2
    }

    It 'reports unclosed frontmatter' {
        $path = Write-Fixture 'fm/e.md' @('---', 'name: x', 'Body')
        (Read-Frontmatter -Path $path).Error | Should -Match 'not closed'
    }
}

Describe 'Test-AgentFile' {
    It 'accepts a valid agent' {
        @(Test-AgentFile -Path (New-Agent) -Config $Config) | Should -BeNullOrEmpty
    }

    It 'rejects a name that does not match the file name' {
        $path = New-Agent -Id 'sample' -Frontmatter @('name: other', 'description: Fine.')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match 'must match the file name'
    }

    It 'rejects a missing description' {
        $path = New-Agent -Frontmatter @('name: sample')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match 'description is missing'
    }

    It 'rejects a description over the limit' {
        $path = New-Agent -Frontmatter @('name: sample', "description: $('a' * ($Config.maxDescriptionLength + 1))")
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match 'characters; the limit'
    }

    It 'accepts a description exactly at the limit' {
        $path = New-Agent -Frontmatter @('name: sample', "description: $('a' * $Config.maxDescriptionLength)")
        @(Test-AgentFile -Path $path -Config $Config) | Should -BeNullOrEmpty
    }

    It 'rejects an unquoted description that would break YAML' {
        $path = New-Agent -Frontmatter @('name: sample', 'description: Use this when: needed')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match 'Quote it'
    }

    It 'accepts a block-scalar description that contains a colon' {
        $path = New-Agent -Frontmatter @('name: sample', 'description: >', '  Use this when: needed')
        @(Test-AgentFile -Path $path -Config $Config) | Should -BeNullOrEmpty
    }

    It 'rejects handoffs' {
        $path = New-Agent -Frontmatter @('name: sample', 'description: Fine.', 'handoffs:', '  - label: x')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match "'handoffs' isn't allowed"
    }

    It 'rejects tools that are not portable aliases' {
        $path = New-Agent -Frontmatter @('name: sample', 'description: Fine.', 'tools: [read, read_file]')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match "tool 'read_file'"
    }

    It 'rejects a model on any agent other than the worker' {
        $path = New-Agent -Frontmatter @('name: sample', 'description: Fine.', 'model: small-model')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match "only 'developer-worker' may set 'model'"
    }

    It 'accepts an allowed model on the worker' {
        $path = New-Agent -Id 'developer-worker' -Frontmatter @('name: developer-worker', 'description: Fine.', 'model: small-model', 'user-invocable: false')
        @(Test-AgentFile -Path $path -Config $Config) | Should -BeNullOrEmpty
    }

    It 'rejects a model on the worker that is not in the allow-list' {
        $path = New-Agent -Id 'developer-worker' -Frontmatter @('name: developer-worker', 'description: Fine.', 'model: big-model', 'user-invocable: false')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match "model 'big-model' isn't in allowedModels"
    }

    It 'requires the worker to be not user-invocable' {
        $path = New-Agent -Id 'developer-worker' -Frontmatter @('name: developer-worker', 'description: Fine.', 'model: small-model')
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match "'user-invocable' must be false"
    }

    It 'rejects a body over the line budget' {
        $path = New-Agent -BodyLines ($Config.maxAgentBodyLines + 1)
        @(Test-AgentFile -Path $path -Config $Config) | Should -Match 'body is 101 lines'
    }

    It 'accepts a body exactly at the line budget' {
        $path = New-Agent -BodyLines $Config.maxAgentBodyLines
        @(Test-AgentFile -Path $path -Config $Config) | Should -BeNullOrEmpty
    }
}

Describe 'Test-SkillFolder' {
    It 'accepts a valid skill' {
        @(Test-SkillFolder -Path (New-Skill) -Config $Config) | Should -BeNullOrEmpty
    }

    It 'accepts a skill with a metadata map' {
        $root = New-Skill -Frontmatter @('name: sample-skill', 'description: Explains how to record an inspection.', 'metadata:', '  author: defra')
        @(Test-SkillFolder -Path $root -Config $Config) | Should -BeNullOrEmpty
    }

    It 'rejects a missing SKILL.md' {
        $folder = Join-Path $TestDrive 'empty-skill'
        New-Item -ItemType Directory -Path $folder | Out-Null
        @(Test-SkillFolder -Path $folder -Config $Config) | Should -Match 'SKILL.md is missing'
    }

    It 'rejects a name that does not match the folder' {
        $path = New-Skill -Folder 'sample-skill' -Frontmatter @('name: other-skill', 'description: Fine.')
        @(Test-SkillFolder -Path $path -Config $Config) | Should -Match 'must match the folder name'
    }

    It 'rejects a name that is not kebab-case' {
        $path = New-Skill -Folder 'Sample_Skill' -Frontmatter @('name: Sample_Skill', 'description: Fine.')
        @(Test-SkillFolder -Path $path -Config $Config) | Should -Match 'kebab-case'
    }

    It 'rejects a description over the limit' {
        $path = New-Skill -Frontmatter @('name: sample-skill', "description: $('a' * ($Config.maxDescriptionLength + 1))")
        @(Test-SkillFolder -Path $path -Config $Config) | Should -Match 'characters; the limit'
    }

    It 'rejects unknown frontmatter keys' {
        $path = New-Skill -Frontmatter @('name: sample-skill', 'description: Fine.', 'owner: someone')
        @(Test-SkillFolder -Path $path -Config $Config) | Should -Match "unknown frontmatter key 'owner'"
    }

    It 'rejects a body over the line budget' {
        $path = New-Skill -BodyLines ($Config.maxSkillBodyLines + 1)
        @(Test-SkillFolder -Path $path -Config $Config) | Should -Match 'body is 151 lines'
    }

    It 'accepts a body exactly at the line budget' {
        $path = New-Skill -BodyLines $Config.maxSkillBodyLines
        @(Test-SkillFolder -Path $path -Config $Config) | Should -BeNullOrEmpty
    }

    It 'rejects nested folders under references' {
        $path = New-Skill
        New-Item -ItemType Directory -Path (Join-Path $path 'references/deeper') | Out-Null
        @(Test-SkillFolder -Path $path -Config $Config) | Should -Match 'one level deep'
    }
}

Describe 'Test-MarkdownLinks' {
    BeforeEach {
        $script:Plugin = Join-Path $TestDrive "plugin-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path (Join-Path $Plugin 'skills/a/references') | Out-Null
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/a/references/b.md') -Value 'Target'
    }

    It 'accepts relative links that resolve, including anchors' {
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/a/SKILL.md') -Value '[b](references/b.md#top) and [self](#section)'
        @(Test-MarkdownLinks -PluginRoot $Plugin) | Should -BeNullOrEmpty
    }

    It 'ignores external links, code spans and fenced blocks' {
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/a/SKILL.md') -Value @(
            '[x](https://example.com) `[y](missing.md)`', '```', '[z](missing.md)', '```')
        @(Test-MarkdownLinks -PluginRoot $Plugin) | Should -BeNullOrEmpty
    }

    It 'rejects a link to a file that does not exist' {
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/a/SKILL.md') -Value '[b](references/missing.md)'
        @(Test-MarkdownLinks -PluginRoot $Plugin) | Should -Match "doesn't exist"
    }

    It 'rejects a link that leaves the plugin' {
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/a/SKILL.md') -Value '[up](../../../README.md)'
        @(Test-MarkdownLinks -PluginRoot $Plugin) | Should -Match 'leaves the plugin'
    }

    It 'rejects an absolute path' {
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/a/SKILL.md') -Value '[abs](/src/app.md)'
        @(Test-MarkdownLinks -PluginRoot $Plugin) | Should -Match 'absolute path'
    }

    It 'allows links between skills inside the plugin' {
        New-Item -ItemType Directory -Path (Join-Path $Plugin 'skills/c') | Out-Null
        Set-Content -LiteralPath (Join-Path $Plugin 'skills/c/SKILL.md') -Value '[b](../a/references/b.md)'
        @(Test-MarkdownLinks -PluginRoot $Plugin) | Should -BeNullOrEmpty
    }
}

Describe 'Test-Plugin' {
    It 'passes an empty plugin' {
        $plugin = Join-Path $TestDrive "empty-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $plugin | Out-Null
        @(Test-Plugin -PluginRoot $plugin -Config $Config) | Should -BeNullOrEmpty
    }

    It 'collects violations from agents, skills and links' {
        $plugin = Join-Path $TestDrive "mixed-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path (Join-Path $plugin 'agents'), (Join-Path $plugin 'skills/bad') | Out-Null
        Set-Content -LiteralPath (Join-Path $plugin 'agents/one.agent.md') -Value @('---', 'name: two', 'description: Fine.', '---', 'Body')
        Set-Content -LiteralPath (Join-Path $plugin 'skills/bad/SKILL.md') -Value @('---', 'name: bad', 'description: Fine.', '---', '[x](missing.md)')

        $violations = @(Test-Plugin -PluginRoot $plugin -Config $Config)
        $violations.Count | Should -Be 2
    }
}
