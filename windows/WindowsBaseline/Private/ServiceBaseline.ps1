function Get-BaselineServiceState {
    <#
        .SYNOPSIS
        Thin wrapper around Get-Service so Invoke-WindowsBaseline's logic can be unit-tested
        by mocking this function - Get-Service itself is Windows-only and unavailable to
        Pester on a non-Windows development machine.
    #>
    [CmdletBinding()]
    [OutputType([System.ServiceProcess.ServiceController])]
    param(
        [Parameter(Mandatory)] [string] $Name
    )

    Get-Service -Name $Name -ErrorAction SilentlyContinue
}

function Set-BaselineServiceState {
    <#
        .SYNOPSIS
        Thin wrapper around Set-Service/Start-Service/Stop-Service; see Get-BaselineServiceState.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Status,
        [Parameter(Mandatory)] [string] $StartupType
    )

    Set-Service -Name $Name -StartupType $StartupType
    if ($Status -eq 'Running') {
        Start-Service -Name $Name
    } elseif ($Status -eq 'Stopped') {
        Stop-Service -Name $Name -Force
    }
}
