<#
.SYNOPSIS
    Authoring-rule checks for the power-platform-delivery plugin (see docs/authoring-guide.md).

.DESCRIPTION
    Dot-source this file to get the Test-* functions. Each returns an array of violation messages, which is
    empty when the file or folder follows the rules. The limits live in lint.config.json.
#>

Set-StrictMode -Version Latest

function Get-LintConfig {
    <#
    .SYNOPSIS
        Reads lint.config.json.
    .PARAMETER Path
        Path to the configuration file. Defaults to lint.config.json next to this script.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot 'lint.config.json')
    )

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function ConvertFrom-YamlScalar {
    param([string]$Text)

    $value = $Text.Trim()
    if ($value.Length -ge 2) {
        $first = $value[0]
        if (($first -eq '"' -or $first -eq "'") -and $value[-1] -eq $first) {
            $value = $value.Substring(1, $value.Length - 2)
            if ($first -eq "'") { $value = $value.Replace("''", "'") }
        }
    }
    $value
}

function Read-Frontmatter {
    <#
    .SYNOPSIS
        Reads the YAML frontmatter and body size of a Markdown file.
    .DESCRIPTION
        Supports the subset of YAML that agent and skill files use: scalars, quoted scalars, flow lists
        ([a, b]), block lists, maps of scalars (such as metadata) and folded or literal block scalars.
    .PARAMETER Path
        The Markdown file to read.
    .OUTPUTS
        An object with Found, Error, Fields (ordered, key to string, string[] or an ordered map), Quoted (keys
        whose value was quoted or is a block scalar, so ': ' and ' #' are safe in it) and BodyLineCount (lines after the frontmatter, ignoring leading and trailing blanks).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $lines = [System.IO.File]::ReadAllLines($Path)
    $result = [pscustomobject]@{
        Found         = $false
        Error         = $null
        Fields        = [ordered]@{}
        Quoted        = [System.Collections.Generic.HashSet[string]]::new()
        BodyLineCount = 0
    }

    $bodyStart = 0
    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
        $end = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '---') { $end = $i; break }
        }
        if ($end -lt 0) {
            $result.Error = 'The frontmatter is not closed with ---.'
            return $result
        }

        $result.Found = $true
        $bodyStart = $end + 1
        $i = 1
        while ($i -lt $end) {
            $line = $lines[$i]
            if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { $i++; continue }

            if ($line -notmatch '^([A-Za-z][\w-]*)\s*:\s*(.*)$') {
                $problem = "Cannot parse frontmatter line $($i + 1): $line"
                $result.Error = if ($result.Error) { "$($result.Error) $problem" } else { $problem }
                $i++
                continue
            }

            $key = $Matches[1]
            $raw = $Matches[2].Trim()
            $i++

            if ($raw -match '^[>|][+-]?$') {
                $parts = [System.Collections.Generic.List[string]]::new()
                while ($i -lt $end -and ($lines[$i].Trim() -eq '' -or $lines[$i] -match '^\s+')) {
                    $parts.Add($lines[$i].Trim())
                    $i++
                }
                $separator = if ($raw.StartsWith('>')) { ' ' } else { "`n" }
                $result.Fields[$key] = ($parts -join $separator).Trim()
                # A block scalar can contain ': ' and ' #' safely, as a quoted scalar can.
                [void]$result.Quoted.Add($key)
            }
            elseif ($raw -eq '') {
                # A block list (indented or not) or a map of scalars, such as the skill's metadata.
                $items = [System.Collections.Generic.List[string]]::new()
                $map = [ordered]@{}
                while ($i -lt $end) {
                    $next = $lines[$i]
                    if ($next -match '^\s*-\s+(.*)$') { $items.Add((ConvertFrom-YamlScalar $Matches[1])) }
                    elseif ($next -match '^\s+([A-Za-z][\w-]*)\s*:\s*(.*)$') { $map[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2] }
                    elseif ($next.Trim() -ne '') { break }
                    $i++
                }
                $result.Fields[$key] = if ($items.Count -gt 0) { $items.ToArray() } elseif ($map.Count -gt 0) { $map } else { '' }
            }
            elseif ($raw.StartsWith('[') -and $raw.EndsWith(']')) {
                $inner = $raw.Substring(1, $raw.Length - 2)
                $result.Fields[$key] = @($inner -split ',' | ForEach-Object { ConvertFrom-YamlScalar $_ } | Where-Object { $_ -ne '' })
            }
            else {
                if ($raw.Length -ge 2 -and ($raw[0] -eq '"' -or $raw[0] -eq "'")) { [void]$result.Quoted.Add($key) }
                $result.Fields[$key] = ConvertFrom-YamlScalar $raw
            }
        }
    }

    $body = @($lines | Select-Object -Skip $bodyStart)
    $first = 0
    $last = $body.Count - 1
    while ($first -le $last -and $body[$first].Trim() -eq '') { $first++ }
    while ($last -ge $first -and $body[$last].Trim() -eq '') { $last-- }
    $result.BodyLineCount = $last - $first + 1
    $result
}

function Test-Description {
    param($Frontmatter, [string]$Label, $Config, $Violations)

    if (-not $Frontmatter.Fields.Contains('description') -or [string]::IsNullOrWhiteSpace([string]$Frontmatter.Fields['description'])) {
        $Violations.Add("${Label}: the description is missing.")
        return
    }

    $description = [string]$Frontmatter.Fields['description']
    if ($description.Length -gt $Config.maxDescriptionLength) {
        $Violations.Add("${Label}: the description is $($description.Length) characters; the limit is $($Config.maxDescriptionLength).")
    }
    if (-not $Frontmatter.Quoted.Contains('description') -and $description -match ':\s|\s#') {
        $Violations.Add("${Label}: the description contains ': ' or ' #', which breaks unquoted YAML. Quote it or rephrase.")
    }
}

function Test-AgentFile {
    <#
    .SYNOPSIS
        Checks one agent file against the authoring rules.
    .PARAMETER Path
        The <id>.agent.md file.
    .PARAMETER Config
        The lint configuration from Get-LintConfig.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Config
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    $file = Split-Path -Leaf $Path
    $id = $file -replace '\.agent\.md$', ''
    $label = "Agent '$file'"
    $front = Read-Frontmatter -Path $Path

    if (-not $front.Found) {
        $violations.Add("${label}: there is no frontmatter.")
        return $violations.ToArray()
    }
    if ($front.Error) { $violations.Add("${label}: $($front.Error)") }

    $fields = $front.Fields
    if ($file -notmatch '\.agent\.md$') { $violations.Add("${label}: the file name must end in .agent.md.") }
    if (-not $fields.Contains('name')) { $violations.Add("${label}: the name is missing.") }
    elseif ($fields['name'] -ne $id) { $violations.Add("${label}: the name '$($fields['name'])' must match the file name '$id'.") }

    Test-Description -Frontmatter $front -Label $label -Config $Config -Violations $violations

    foreach ($key in $fields.Keys) {
        if ($key -eq 'handoffs') { $violations.Add("${label}: 'handoffs' isn't allowed. Describe handoffs in prose.") }
        elseif ($key -notin $Config.agentFrontmatterKeys) { $violations.Add("${label}: unknown frontmatter key '$key'.") }
    }

    if ($fields.Contains('tools')) {
        foreach ($tool in @($fields['tools'])) {
            if ($tool -notin $Config.agentToolAliases) {
                $violations.Add("${label}: tool '$tool' isn't a portable alias ($($Config.agentToolAliases -join ', ')).")
            }
        }
    }

    if ($fields.Contains('model')) {
        if ($id -ne $Config.modelAgent) {
            $violations.Add("${label}: only '$($Config.modelAgent)' may set 'model'.")
        }
        else {
            foreach ($model in @($fields['model'])) {
                if ($model -notin @($Config.allowedModels)) {
                    $violations.Add("${label}: model '$model' isn't in allowedModels in lint.config.json.")
                }
            }
        }
    }
    if ($id -eq $Config.modelAgent -and [string]$fields['user-invocable'] -ne 'false') {
        $violations.Add("${label}: 'user-invocable' must be false.")
    }

    if ($front.BodyLineCount -gt $Config.maxAgentBodyLines) {
        $violations.Add("${label}: the body is $($front.BodyLineCount) lines; the limit is $($Config.maxAgentBodyLines).")
    }

    $violations.ToArray()
}

function Test-SkillFolder {
    <#
    .SYNOPSIS
        Checks one skill folder against the authoring rules.
    .PARAMETER Path
        The skills/<name> folder.
    .PARAMETER Config
        The lint configuration from Get-LintConfig.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Config
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    $folder = Split-Path -Leaf $Path
    $label = "Skill '$folder'"
    $skillFile = Join-Path $Path 'SKILL.md'

    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        $violations.Add("${label}: SKILL.md is missing.")
        return $violations.ToArray()
    }

    $front = Read-Frontmatter -Path $skillFile
    if (-not $front.Found) {
        $violations.Add("${label}: there is no frontmatter.")
        return $violations.ToArray()
    }
    if ($front.Error) { $violations.Add("${label}: $($front.Error)") }

    $fields = $front.Fields
    if (-not $fields.Contains('name')) {
        $violations.Add("${label}: the name is missing.")
    }
    else {
        $name = [string]$fields['name']
        if ($name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $violations.Add("${label}: the name '$name' must be kebab-case.") }
        if ($name.Length -gt $Config.maxSkillNameLength) { $violations.Add("${label}: the name is longer than $($Config.maxSkillNameLength) characters.") }
        if ($name -ne $folder) { $violations.Add("${label}: the name '$name' must match the folder name.") }
    }

    Test-Description -Frontmatter $front -Label $label -Config $Config -Violations $violations

    foreach ($key in $fields.Keys) {
        if ($key -notin $Config.skillFrontmatterKeys) { $violations.Add("${label}: unknown frontmatter key '$key'.") }
    }

    if ($front.BodyLineCount -gt $Config.maxSkillBodyLines) {
        $violations.Add("${label}: SKILL.md body is $($front.BodyLineCount) lines; the limit is $($Config.maxSkillBodyLines). Move detail to references/.")
    }

    $references = Join-Path $Path 'references'
    if (Test-Path -LiteralPath $references) {
        foreach ($nested in Get-ChildItem -LiteralPath $references -Directory) {
            $violations.Add("${label}: references/$($nested.Name) is a folder; references must be one level deep.")
        }
    }

    $violations.ToArray()
}

function Test-MarkdownLinks {
    <#
    .SYNOPSIS
        Checks that every relative Markdown link in the plugin resolves to a file or folder inside the plugin.
    .PARAMETER PluginRoot
        The plugin folder (the one containing plugin.json).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PluginRoot
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    $root = [System.IO.Path]::GetFullPath($PluginRoot).TrimEnd('\', '/')
    $rootPrefix = $root + [System.IO.Path]::DirectorySeparatorChar

    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.md') {
        $relativeFile = [System.IO.Path]::GetRelativePath($root, $file.FullName)
        $inFence = $false
        $lineNumber = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $lineNumber++
            if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
            if ($inFence) { continue }

            $text = [regex]::Replace($line, '`[^`]*`', '')
            foreach ($match in [regex]::Matches($text, '\[[^\]]*\]\((<[^>]+>|[^)\s]+)(?:\s+"[^"]*")?\)')) {
                $target = $match.Groups[1].Value.Trim('<', '>')
                if ($target -match '^(https?:|mailto:|#)') { continue }

                $path = [System.Uri]::UnescapeDataString(($target -split '#')[0])
                if ($path -eq '') { continue }

                $where = "${relativeFile}:${lineNumber}"
                if ([System.IO.Path]::IsPathRooted($path) -or $path.StartsWith('/') -or $path.StartsWith('\')) {
                    $violations.Add("${where}: the link '$target' is an absolute path; links must be relative and inside the plugin.")
                    continue
                }

                $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $path)).TrimEnd('\', '/')
                if ($resolved -ne $root -and -not $resolved.StartsWith($rootPrefix, [System.StringComparison]::Ordinal)) {
                    $violations.Add("${where}: the link '$target' leaves the plugin.")
                }
                elseif (-not (Test-Path -LiteralPath $resolved)) {
                    $violations.Add("${where}: the link '$target' doesn't exist.")
                }
            }
        }
    }

    $violations.ToArray()
}

function Test-Plugin {
    <#
    .SYNOPSIS
        Runs every authoring-rule check against a plugin folder.
    .PARAMETER PluginRoot
        The plugin folder (the one containing plugin.json).
    .PARAMETER Config
        The lint configuration from Get-LintConfig.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PluginRoot,
        [Parameter(Mandatory)]$Config
    )

    $violations = [System.Collections.Generic.List[string]]::new()

    $agents = Join-Path $PluginRoot 'agents'
    if (Test-Path -LiteralPath $agents) {
        foreach ($file in Get-ChildItem -LiteralPath $agents -File -Filter '*.md') {
            $violations.AddRange([string[]]@(Test-AgentFile -Path $file.FullName -Config $Config))
        }
    }

    $skills = Join-Path $PluginRoot 'skills'
    if (Test-Path -LiteralPath $skills) {
        foreach ($folder in Get-ChildItem -LiteralPath $skills -Directory) {
            $violations.AddRange([string[]]@(Test-SkillFolder -Path $folder.FullName -Config $Config))
        }
    }

    $violations.AddRange([string[]]@(Test-MarkdownLinks -PluginRoot $PluginRoot))

    $violations.ToArray()
}
