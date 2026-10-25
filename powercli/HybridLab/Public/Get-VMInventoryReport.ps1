function Get-VMInventoryReport {
    <#
        .SYNOPSIS
        Reports the current VM inventory (with each VM's owner/expiry/protected marker)
        and, optionally, drift against a desired-state file.

        .PARAMETER DesiredStatePath
        Path to a JSON file: an array of objects with at least a Name, and optionally
        PowerState, NumCpu and/or MemoryGB to check for drift. See
        powercli/examples/desired-state.sample.json.

        .PARAMETER NamePattern
        Wildcard pattern (e.g. 'lab-*') that scopes both the inventory and, when a desired
        state is given, the 'Unexpected' drift check (a VM matching the pattern that is not
        in the desired state). Without it, only 'Missing'/'Mismatch' drift is reported, since
        most vSphere inventories contain plenty of VMs this module was never asked to manage.

        .EXAMPLE
        Get-VMInventoryReport -DesiredStatePath ./desired-state.json -NamePattern 'lab-*'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string] $DesiredStatePath,
        [string] $NamePattern
    )

    $allVMs = Get-VM
    $scopedVMs = if ($NamePattern) { $allVMs | Where-Object { $_.Name -like $NamePattern } } else { $allVMs }

    $inventory = foreach ($vm in $scopedVMs) {
        $marker = Get-LabVMMarker -VM $vm
        [PSCustomObject]@{
            Name       = $vm.Name
            PowerState = $vm.PowerState.ToString()
            NumCpu     = $vm.NumCpu
            MemoryGB   = $vm.MemoryGB
            Owner      = $marker.Owner
            Expiry     = $marker.Expiry
            Protected  = $marker.Protected
            Marker     = $marker.Strategy
        }
    }
    $inventory = @($inventory)

    $drift = [System.Collections.Generic.List[object]]::new()

    if ($DesiredStatePath) {
        $desired = @(Get-Content -Path $DesiredStatePath -Raw | ConvertFrom-Json)

        foreach ($expected in $desired) {
            $actual = $inventory | Where-Object { $_.Name -eq $expected.Name } | Select-Object -First 1
            if (-not $actual) {
                $drift.Add([PSCustomObject]@{ Name = $expected.Name; Kind = 'Missing'; Detail = 'expected VM not found in inventory' })
                continue
            }

            foreach ($prop in 'PowerState', 'NumCpu', 'MemoryGB') {
                if ($expected.PSObject.Properties.Name -contains $prop -and "$($actual.$prop)" -ne "$($expected.$prop)") {
                    $drift.Add([PSCustomObject]@{
                        Name   = $expected.Name
                        Kind   = 'Mismatch'
                        Detail = "$prop expected '$($expected.$prop)' actual '$($actual.$prop)'"
                    })
                }
            }
        }

        if ($NamePattern) {
            $desiredNames = @($desired | ForEach-Object { $_.Name })
            foreach ($actual in $inventory) {
                if ($desiredNames -notcontains $actual.Name) {
                    $drift.Add([PSCustomObject]@{ Name = $actual.Name; Kind = 'Unexpected'; Detail = 'matches NamePattern but is not in the desired state' })
                }
            }
        }
    }

    [PSCustomObject]@{
        GeneratedAt = (Get-Date).ToUniversalTime()
        Inventory   = $inventory
        Drift       = @($drift)
        HasDrift    = ($drift.Count -gt 0)
    }
}
