function Invoke-SnapshotPolicy {
    <#
        .SYNOPSIS
        Applies a snapshot lifecycle policy to one or more VMs: optionally creates a new
        snapshot, then prunes snapshots older than the retention window. Refuses to touch
        any VM marked protected (via tag or Notes marker; see Get-LabVMMarker).

        .PARAMETER VM
        One or more VM objects (e.g. from Get-VM) or VM names.

        .PARAMETER RetentionDays
        Snapshots named "$SnapshotNamePrefix*" older than this many days are removed.
        A negative value prunes every matching snapshot regardless of age.

        .EXAMPLE
        Get-VM -Name 'lab-*' | Invoke-SnapshotPolicy -CreateSnapshot -RetentionDays 7 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [PSObject[]] $VM,
        [int] $RetentionDays = 7,
        [string] $SnapshotNamePrefix = 'hybridlab-auto',
        [switch] $CreateSnapshot
    )

    begin {
        $results = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($target in $VM) {
            $vmObj = if ($target -is [string]) { Get-VM -Name $target -ErrorAction Stop | Select-Object -First 1 } else { $target }

            $marker = Get-LabVMMarker -VM $vmObj
            if ($marker.Protected) {
                Write-Warning "Skipping protected VM '$($vmObj.Name)': the snapshot policy refuses to touch protected VMs."
                $results.Add([PSCustomObject]@{ VM = $vmObj.Name; Action = 'Skipped'; Reason = 'protected'; Snapshot = $null })
                continue
            }

            if ($CreateSnapshot) {
                $snapshotName = "$SnapshotNamePrefix-$((Get-Date).ToString('yyyyMMddHHmmssfff'))"
                if ($PSCmdlet.ShouldProcess($vmObj.Name, "Create snapshot '$snapshotName'")) {
                    New-Snapshot -VM $vmObj -Name $snapshotName -Confirm:$false | Out-Null
                    $results.Add([PSCustomObject]@{ VM = $vmObj.Name; Action = 'Created'; Reason = $null; Snapshot = $snapshotName })
                }
            }

            $threshold = (Get-Date).AddDays(-$RetentionDays)
            $stale = Get-Snapshot -VM $vmObj -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$SnapshotNamePrefix*" -and $_.Created -lt $threshold }

            foreach ($snapshot in $stale) {
                if ($PSCmdlet.ShouldProcess($vmObj.Name, "Remove stale snapshot '$($snapshot.Name)' (created $($snapshot.Created))")) {
                    Remove-Snapshot -Snapshot $snapshot -Confirm:$false | Out-Null
                    $results.Add([PSCustomObject]@{ VM = $vmObj.Name; Action = 'Pruned'; Reason = 'retention expired'; Snapshot = $snapshot.Name })
                }
            }
        }
    }

    end {
        $results
    }
}
