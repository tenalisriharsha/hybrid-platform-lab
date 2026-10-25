BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'HybridLab') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Get-VMInventoryReport' -ForEach @(
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

    It "reports every VM when no NamePattern is given (<Mode>)" {
        $report = Get-VMInventoryReport

        $report.Inventory.Count | Should -Be (Get-VM).Count
        $report.HasDrift | Should -BeFalse
    }

    It "flags a missing VM against a desired-state file (<Mode>)" {
        $desired = @(@{ Name = 'does-not-exist-vm'; PowerState = 'PoweredOn' })
        $path = Join-Path $TestDrive 'desired-missing.json'
        $desired | ConvertTo-Json -AsArray | Set-Content -Path $path

        $report = Get-VMInventoryReport -DesiredStatePath $path

        $report.HasDrift | Should -BeTrue
        ($report.Drift | Where-Object Kind -EQ 'Missing').Name | Should -Contain 'does-not-exist-vm'
    }

    It "flags a power-state mismatch against a desired-state file (<Mode>)" {
        $existing = Get-VM | Select-Object -First 1
        $existing.PowerState.ToString() | Should -Be 'PoweredOn'

        $desired = @(@{ Name = $existing.Name; PowerState = 'PoweredOff' })
        $path = Join-Path $TestDrive 'desired-mismatch.json'
        $desired | ConvertTo-Json -AsArray | Set-Content -Path $path

        $report = Get-VMInventoryReport -DesiredStatePath $path

        $report.HasDrift | Should -BeTrue
        $mismatch = $report.Drift | Where-Object { $_.Name -eq $existing.Name -and $_.Kind -eq 'Mismatch' }
        $mismatch | Should -Not -BeNullOrEmpty
        $mismatch.Detail | Should -Match 'PowerState'
    }

    It "reports no drift when the desired state matches reality (<Mode>)" {
        $existing = Get-VM | Select-Object -First 1
        $desired = @(@{ Name = $existing.Name; PowerState = $existing.PowerState.ToString() })
        $path = Join-Path $TestDrive 'desired-match.json'
        $desired | ConvertTo-Json -AsArray | Set-Content -Path $path

        $report = Get-VMInventoryReport -DesiredStatePath $path

        $report.HasDrift | Should -BeFalse
    }

    It "flags an unexpected VM when scoped by -NamePattern (<Mode>)" {
        $name = "lab-unexpected-$($Mode.ToLower())-$(Get-Random)"
        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null

        $desired = @(@{ Name = 'some-other-lab-vm'; PowerState = 'PoweredOn' })
        $path = Join-Path $TestDrive 'desired-unexpected.json'
        $desired | ConvertTo-Json -AsArray | Set-Content -Path $path

        $report = Get-VMInventoryReport -DesiredStatePath $path -NamePattern 'lab-*'

        ($report.Drift | Where-Object Kind -EQ 'Unexpected').Name | Should -Contain $name

        Remove-VM -VM (Get-VM -Name $name) -DeletePermanently -Confirm:$false
    }
}
