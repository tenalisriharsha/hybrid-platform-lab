#Requires -Version 7.0
<#
    .SYNOPSIS
    Runs PSScriptAnalyzer and the Pester suite for the HybridPlatformSync module.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

Import-Module PSScriptAnalyzer -Force
$lintResults = Invoke-ScriptAnalyzer -Path $here -Recurse -Settings PSGallery
if ($lintResults) {
    $lintResults | Format-Table -AutoSize
    throw 'PSScriptAnalyzer found issues (see above).'
}
Write-Host 'PSScriptAnalyzer: clean.' -ForegroundColor Green

Import-Module Pester -MinimumVersion 5.0 -Force
$config = New-PesterConfiguration
$config.Run.Path = Join-Path -Path $here -ChildPath 'Tests'
$config.Run.Exit = $false
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) Pester test(s) failed."
}
Write-Host "Pester: $($result.PassedCount) passed, $($result.FailedCount) failed." -ForegroundColor Green
