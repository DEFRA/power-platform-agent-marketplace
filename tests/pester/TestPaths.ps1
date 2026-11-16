# Locates the repository and the plugin under test. Dot-source it; Pester runs only *.Tests.ps1 files, so this isn't a test.
# The plugin's folder name appears here and nowhere else in the tests.

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:PluginRoot = Join-Path $script:RepoRoot 'plugins/power-platform-delivery'
