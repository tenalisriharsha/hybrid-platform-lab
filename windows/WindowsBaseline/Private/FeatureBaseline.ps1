function Get-BaselineFeatureState {
    <#
        .SYNOPSIS
        Thin wrapper around Get-WindowsFeature; see Get-BaselineServiceState for why this
        module wraps every Windows-only cmdlet instead of calling it directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name
    )

    Get-WindowsFeature -Name $Name -ErrorAction SilentlyContinue
}

function Install-BaselineFeature {
    <#
        .SYNOPSIS
        Thin wrapper around Install-WindowsFeature; see Get-BaselineServiceState.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name
    )

    Install-WindowsFeature -Name $Name -ErrorAction Stop
}
