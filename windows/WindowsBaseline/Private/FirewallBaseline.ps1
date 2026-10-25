function Get-BaselineFirewallProfile {
    <#
        .SYNOPSIS
        Thin wrapper around Get-NetFirewallProfile; see Get-BaselineServiceState for why this
        module wraps every Windows-only cmdlet instead of calling it directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name
    )

    Get-NetFirewallProfile -Name $Name -ErrorAction SilentlyContinue
}

function Enable-BaselineFirewallProfile {
    <#
        .SYNOPSIS
        Thin wrapper around Set-NetFirewallProfile; see Get-BaselineServiceState.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name
    )

    Set-NetFirewallProfile -Name $Name -Enabled True
}
