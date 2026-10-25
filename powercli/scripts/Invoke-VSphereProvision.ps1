<#
    .SYNOPSIS
    Entry point the API's vSphere backend shells out to: connects to vCenter/ESXi and
    calls New-LabVM. The password is read from HYBRID_LAB_VSPHERE_PASSWORD (inherited
    from the caller's environment) rather than taken as a parameter, so it never appears
    in a process listing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Server,
    [int] $Port = 443,
    [Parameter(Mandatory)] [string] $User,
    [Parameter(Mandatory)] [string] $ModulePath,
    [Parameter(Mandatory)] [string] $TemplateName,
    [Parameter(Mandatory)] [string] $Name,
    [string] $PortGroup,
    [Parameter(Mandatory)] [string] $Owner,
    [Parameter(Mandatory)] [string] $Expiry
)

$ErrorActionPreference = 'Stop'

$password = $env:HYBRID_LAB_VSPHERE_PASSWORD
if (-not $password) {
    throw 'HYBRID_LAB_VSPHERE_PASSWORD is not set in the environment'
}

Import-Module $ModulePath -Force
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false -Scope Session -Confirm:$false | Out-Null
Connect-VIServer -Server $Server -Port $Port -User $User -Password $password -Force | Out-Null

try {
    $vmHost = Get-VMHost | Select-Object -First 1
    $params = @{
        TemplateName = $TemplateName
        Name         = $Name
        VMHost       = $vmHost
        Owner        = $Owner
        Expiry       = $Expiry
        Confirm      = $false
    }
    if ($PortGroup) {
        $params.PortGroup = $PortGroup
    }

    $result = New-LabVM @params
    $result | ConvertTo-Json -Compress
}
finally {
    Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue
}
