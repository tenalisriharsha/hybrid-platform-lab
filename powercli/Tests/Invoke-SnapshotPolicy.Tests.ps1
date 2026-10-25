BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'HybridLab') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Invoke-SnapshotPolicy' -ForEach @(
    @{ Mode = 'vCenter' }
    @{ Mode = 'ESXi' }
) {
    BeforeAll {
        $script:conn = Connect-HybridLabTestServer -Mode $Mode
        $script:templateName = Get-VM | Select-Object -First 1 -ExpandProperty Name
        $script:vmHost = Get-VMHost | Select-Object -First 1
    }

    AfterAll {
        Disconnect-VIServer -Server $script:conn -Confirm:$false -ErrorAction SilentlyContinue
    }

    It "creates a snapshot for an unprotected VM (<Mode>)" {
        $name = "lab-snap-$($Mode.ToLower())-$(Get-Random)"
        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
        $vm = Get-VM -Name $name

        $result = Invoke-SnapshotPolicy -VM $vm -CreateSnapshot -Confirm:$false

        ($result | Where-Object Action -EQ 'Created').VM | Should -Contain $name
        (Get-Snapshot -VM $vm).Count | Should -BeGreaterThan 0

        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
    }

    It "refuses to touch a VM marked protected (<Mode>)" {
        $name = "lab-snap-protected-$($Mode.ToLower())-$(Get-Random)"
        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost -Protected `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
        $vm = Get-VM -Name $name

        $result = Invoke-SnapshotPolicy -VM $vm -CreateSnapshot -Confirm:$false -WarningAction SilentlyContinue

        ($result | Where-Object Action -EQ 'Skipped').Reason | Should -Contain 'protected'
        Get-Snapshot -VM $vm -ErrorAction SilentlyContinue | Should -BeNullOrEmpty

        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
    }

    It "supports -WhatIf and does not create a snapshot (<Mode>)" {
        $name = "lab-snap-whatif-$($Mode.ToLower())-$(Get-Random)"
        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
        $vm = Get-VM -Name $name

        Invoke-SnapshotPolicy -VM $vm -CreateSnapshot -WhatIf

        Get-Snapshot -VM $vm -ErrorAction SilentlyContinue | Should -BeNullOrEmpty

        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
    }

    It "prunes snapshots within the retention window when RetentionDays forces it (<Mode>)" {
        $name = "lab-snap-prune-$($Mode.ToLower())-$(Get-Random)"
        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
        $vm = Get-VM -Name $name
        New-Snapshot -VM $vm -Name 'hybridlab-auto-existing' -Confirm:$false | Out-Null

        # vcsim always stamps Created as "now", so a real multi-day-old snapshot can't be
        # staged here. RetentionDays -1 moves the cutoff into the future, which any
        # already-created snapshot is older than - this exercises the real pruning
        # comparison deterministically instead of relying on clock skew.
        $result = Invoke-SnapshotPolicy -VM $vm -RetentionDays -1 -Confirm:$false

        ($result | Where-Object Action -EQ 'Pruned').Snapshot | Should -Contain 'hybridlab-auto-existing'
        Get-Snapshot -VM $vm -ErrorAction SilentlyContinue | Should -BeNullOrEmpty

        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
    }

    It "does not prune a snapshot that is within the retention window (<Mode>)" {
        $name = "lab-snap-keep-$($Mode.ToLower())-$(Get-Random)"
        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null
        $vm = Get-VM -Name $name
        New-Snapshot -VM $vm -Name 'hybridlab-auto-fresh' -Confirm:$false | Out-Null

        $result = Invoke-SnapshotPolicy -VM $vm -RetentionDays 7 -Confirm:$false

        ($result | Where-Object Action -EQ 'Pruned') | Should -BeNullOrEmpty
        (Get-Snapshot -VM $vm).Name | Should -Contain 'hybridlab-auto-fresh'

        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
    }
}
