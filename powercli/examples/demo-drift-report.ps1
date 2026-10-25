<#
.SYNOPSIS
    Demonstrates Get-VMInventoryReport against a local vcsim (vCenter mode).
.DESCRIPTION
    Creates three lab VMs with New-LabVM (vcsim clones start powered off), then compares the lab-* inventory
    with desired-state.demo.json: lab-dev-box-1 is desired on but is off (Mismatch), lab-ci-runner-1 matches,
    lab-qa-box-1 does not exist (Missing) and lab-extra-1 is not in the desired state (Unexpected).
    Requires a vcsim container in vCenter mode:  docker run -d -p 8989:8989 vmware/vcsim -l :8989
    Set HPL_VCSIM_VCENTER_PORT if it listens elsewhere. Nothing here touches a real vSphere.
#>
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'HybridLab') -Force
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false -Scope Session -Confirm:$false | Out-Null
$port = if ($env:HPL_VCSIM_VCENTER_PORT) { $env:HPL_VCSIM_VCENTER_PORT } else { '8989' }
$null = Connect-VIServer -Server '127.0.0.1' -Port $port -User 'user' -Password 'pass' -Force -WarningAction SilentlyContinue

$template = Get-VM | Select-Object -First 1 -ExpandProperty Name
$vmHost = Get-VMHost | Select-Object -First 1
foreach ($name in 'lab-dev-box-1', 'lab-ci-runner-1', 'lab-extra-1') {
    New-LabVM -TemplateName $template -Name $name -VMHost $vmHost -Owner 'alice@example.com' `
        -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
}

$report = Get-VMInventoryReport -DesiredStatePath (Join-Path $PSScriptRoot 'desired-state.demo.json') -NamePattern 'lab-*'
"Inventory: $($report.Inventory.Count) VMs   Drift detected: $($report.HasDrift)"
$report.Drift | Format-Table Kind, Name, Detail -AutoSize -Wrap | Out-String -Width 140

Disconnect-VIServer -Confirm:$false
