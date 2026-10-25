<#
.SYNOPSIS
    Demonstrates Invoke-SnapshotPolicy -WhatIf against a local vcsim (vCenter mode).
.DESCRIPTION
    Creates two ordinary lab VMs and one marked protected, then previews a snapshot policy run across all
    three with -WhatIf: the ordinary VMs would be snapshotted, the protected VM is refused. Nothing is changed.
    Requires a vcsim container in vCenter mode:  docker run -d -p 8989:8989 vmware/vcsim -l :8989
#>
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'HybridLab') -Force
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false -Scope Session -Confirm:$false | Out-Null
$port = if ($env:HPL_VCSIM_VCENTER_PORT) { $env:HPL_VCSIM_VCENTER_PORT } else { '8989' }
$null = Connect-VIServer -Server '127.0.0.1' -Port $port -User 'user' -Password 'pass' -Force -WarningAction SilentlyContinue

$template = Get-VM | Select-Object -First 1 -ExpandProperty Name
$vmHost = Get-VMHost | Select-Object -First 1
New-LabVM -TemplateName $template -Name 'lab-dev-box-1' -VMHost $vmHost -Owner 'alice@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
New-LabVM -TemplateName $template -Name 'lab-ci-runner-1' -VMHost $vmHost -Owner 'bob@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
New-LabVM -TemplateName $template -Name 'lab-prod-db-1' -VMHost $vmHost -Owner 'dba@example.com' -Expiry '2099-01-01T00:00:00Z' -Protected -Confirm:$false | Out-Null

$result = Get-VM -Name 'lab-*' | Invoke-SnapshotPolicy -CreateSnapshot -WhatIf -WarningAction Continue
$result | Format-Table VM, Action, Reason -AutoSize | Out-String -Width 140

Disconnect-VIServer -Confirm:$false
