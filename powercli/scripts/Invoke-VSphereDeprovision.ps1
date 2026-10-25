<#
    .SYNOPSIS
    Entry point the API's vSphere backend shells out to for DELETE /environments:
    connects to vCenter/ESXi and permanently removes the VM identified by BackendRef
    (the Id New-LabVM returned at creation time). The password is read from
    HYBRID_LAB_VSPHERE_PASSWORD rather than taken as a parameter.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Server,
    [int] $Port = 443,
    [Parameter(Mandatory)] [string] $User,
    [Parameter(Mandatory)] [string] $BackendRef
)

$ErrorActionPreference = 'Stop'

$password = $env:HYBRID_LAB_VSPHERE_PASSWORD
if (-not $password) {
    throw 'HYBRID_LAB_VSPHERE_PASSWORD is not set in the environment'
}

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false -Scope Session -Confirm:$false | Out-Null
Connect-VIServer -Server $Server -Port $Port -User $User -Password $password -Force | Out-Null

try {
    $vm = Get-VM -Id $BackendRef -ErrorAction Stop
    Remove-VM -VM $vm -DeletePermanently -Confirm:$false
}
finally {
    Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue
}
