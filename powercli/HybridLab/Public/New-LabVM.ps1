function New-LabVM {
    <#
        .SYNOPSIS
        Clones a VM from a template, attaches it to a port group, and marks it with an
        owner, an expiry, and whether it is protected from the snapshot lifecycle policy.

        .PARAMETER TemplateName
        Name of an existing VM or template to clone from.

        .PARAMETER Expiry
        ISO 8601 timestamp (e.g. '2026-11-01T00:00:00Z') at which the environment expires.
        Taken as a string, not [datetime], so it round-trips exactly through the marker and
        through a non-interactive pwsh invocation from another process (the API backend).

        .EXAMPLE
        New-LabVM -TemplateName 'tpl-ubuntu-2204' -Name 'dev-box-1' -VMHost (Get-VMHost | Select -First 1) `
            -PortGroup 'VM Network' -Owner 'alice@example.com' -Expiry '2026-11-01T00:00:00Z'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string] $TemplateName,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [PSObject] $VMHost,
        [string] $Datastore,
        [string] $PortGroup,
        [Parameter(Mandatory)] [string] $Owner,
        [Parameter(Mandatory)] [string] $Expiry,
        [switch] $Protected,
        [ValidateSet('Auto', 'Tag', 'Notes')] [string] $MarkerStrategy = 'Auto'
    )

    $template = Get-VM -Name $TemplateName -ErrorAction Stop | Select-Object -First 1

    if (-not $PSCmdlet.ShouldProcess($Name, "Clone VM from template '$TemplateName'")) {
        return
    }

    $cloneParams = @{
        VM      = $template
        Name    = $Name
        VMHost  = $VMHost
        Confirm = $false
    }
    if ($Datastore) {
        $cloneParams.Datastore = Get-Datastore -Name $Datastore -ErrorAction Stop
    }

    $vm = New-VM @cloneParams

    if ($PortGroup) {
        # Fail fast with a clear error if the port group doesn't exist on this host.
        # Standard portgroup names (e.g. "VM Network") are commonly repeated across every
        # host sharing the same internal key, so resolving one as an object and handing it
        # to -PortGroup re-triggers that cross-host ambiguity inside Set-NetworkAdapter;
        # -NetworkName resolves by name scoped to the adapter's own VM/host instead.
        Get-VirtualPortGroup -VMHost $VMHost -Name $PortGroup -Standard -ErrorAction Stop | Out-Null
        Get-NetworkAdapter -VM $vm | Select-Object -First 1 | Set-NetworkAdapter -NetworkName $PortGroup -Confirm:$false | Out-Null
    }

    Set-LabVMMarker -VM $vm -Owner $Owner -Expiry $Expiry -Protected:([bool]$Protected) -Strategy $MarkerStrategy

    $vm = Get-VM -Id $vm.Id

    [PSCustomObject]@{
        Name       = $vm.Name
        Id         = $vm.Id
        PowerState = $vm.PowerState.ToString()
        Template   = $TemplateName
        PortGroup  = $PortGroup
        Owner      = $Owner
        Expiry     = $Expiry
        Protected  = [bool]$Protected
    }
}
