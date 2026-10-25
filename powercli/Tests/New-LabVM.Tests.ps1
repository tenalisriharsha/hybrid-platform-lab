BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'HybridLab') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'New-LabVM' -ForEach @(
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

    It "clones a VM from a template and marks it with owner/expiry (<Mode>)" {
        $name = "lab-newvm-$($Mode.ToLower())-$(Get-Random)"

        $result = New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false

        $result.Name | Should -Be $name
        $result.Owner | Should -Be 'owner@example.com'
        $result.Protected | Should -BeFalse

        $report = Get-VMInventoryReport -NamePattern $name
        $entry = $report.Inventory | Where-Object Name -EQ $name
        $entry.Owner | Should -Be 'owner@example.com'
        $entry.Expiry | Should -Be '2099-01-01T00:00:00Z'
        $entry.Protected | Should -BeFalse

        Remove-VM -VM (Get-VM -Name $name) -DeletePermanently -Confirm:$false
    }

    It "attaches the requested port group (<Mode>)" {
        $name = "lab-newvm-pg-$($Mode.ToLower())-$(Get-Random)"
        $portGroup = Get-VirtualPortGroup -Standard | Select-Object -First 1 -ExpandProperty Name

        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost -PortGroup $portGroup `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null

        $adapter = Get-NetworkAdapter -VM (Get-VM -Name $name) | Select-Object -First 1
        $adapter.NetworkName | Should -Be $portGroup

        Remove-VM -VM (Get-VM -Name $name) -DeletePermanently -Confirm:$false
    }

    It "marks a VM as protected when -Protected is specified (<Mode>)" {
        $name = "lab-newvm-protected-$($Mode.ToLower())-$(Get-Random)"

        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost -Protected `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -Confirm:$false | Out-Null

        $report = Get-VMInventoryReport -NamePattern $name
        ($report.Inventory | Where-Object Name -EQ $name).Protected | Should -BeTrue

        Remove-VM -VM (Get-VM -Name $name) -DeletePermanently -Confirm:$false
    }

    It "supports -WhatIf and does not create a VM (<Mode>)" {
        $name = "lab-newvm-whatif-$($Mode.ToLower())-$(Get-Random)"

        New-LabVM -TemplateName $script:templateName -Name $name -VMHost $script:vmHost `
            -Owner 'owner@example.com' -Expiry '2099-01-01T00:00:00Z' -WhatIf

        { Get-VM -Name $name -ErrorAction Stop } | Should -Throw
    }
}
