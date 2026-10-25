BeforeAll {
    $moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'HybridPlatformSync'
    Import-Module (Join-Path -Path $moduleRoot -ChildPath 'HybridPlatformSync.psd1') -Force
}

AfterAll {
    Remove-Module HybridPlatformSync -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-InventoryDatastore' {
    It 'maps a PowerCLI-shaped datastore to the platform-api JSON shape' {
        $fakeDatastore = [pscustomobject]@{
            Id          = 'Datastore-datastore-13'
            Name        = 'LocalDS_0'
            CapacityGB  = 4096.0
            FreeSpaceGB = 4056.4
        }

        $result = ConvertTo-InventoryDatastore -Datastore $fakeDatastore

        $result.id | Should -Be 'Datastore-datastore-13'
        $result.name | Should -Be 'LocalDS_0'
        $result.capacityGb | Should -Be 4096
        $result.freeGb | Should -Be 4056
        $result.freeGb | Should -BeOfType [long]
    }
}

Describe 'ConvertTo-InventoryHost' {
    It 'maps a PowerCLI-shaped VMHost, folding in cluster and datastore ids' {
        $fakeHost = [pscustomobject]@{
            Id            = 'HostSystem-host-37'
            Name          = 'DC0_C0_H0'
            NumCpu        = 2
            MemoryTotalGB = 4.0
        }

        $result = ConvertTo-InventoryHost -VMHost $fakeHost -Cluster 'DC0_C0' -DatastoreIds @('Datastore-datastore-13')

        $result.id | Should -Be 'HostSystem-host-37'
        $result.cluster | Should -Be 'DC0_C0'
        $result.cpuCores | Should -Be 2
        $result.memoryMb | Should -Be 4096
        $result.datastoreIds | Should -Be @('Datastore-datastore-13')
    }

    It 'falls back to "standalone" when the host has no cluster' {
        $fakeHost = [pscustomobject]@{
            Id            = 'HostSystem-host-21'
            Name          = 'DC0_H0'
            NumCpu        = 2
            MemoryTotalGB = 4.0
        }

        $result = ConvertTo-InventoryHost -VMHost $fakeHost -Cluster $null -DatastoreIds @()

        $result.cluster | Should -Be 'standalone'
        , $result.datastoreIds | Should -BeOfType [object[]]
        $result.datastoreIds.Count | Should -Be 0
    }
}

Describe 'ConvertTo-InventoryVm' {
    It 'maps a PowerCLI-shaped VM and translates its power state' {
        $fakeVm = [pscustomobject]@{
            Id         = 'VirtualMachine-vm-62'
            Name       = 'DC0_H0_VM0'
            VMHostId   = 'HostSystem-host-21'
            PowerState = 'PoweredOn'
            NumCpu     = 1
            MemoryGB   = 0.5
        }

        $result = ConvertTo-InventoryVm -Vm $fakeVm

        $result.id | Should -Be 'VirtualMachine-vm-62'
        $result.hostId | Should -Be 'HostSystem-host-21'
        $result.powerState | Should -Be 'POWERED_ON'
        $result.cpuCount | Should -Be 1
        $result.memoryMb | Should -Be 512
    }

    It 'translates PoweredOff and Suspended states' {
        $poweredOff = [pscustomobject]@{ Id='vm-1'; Name='a'; VMHostId='h-1'; PowerState='PoweredOff'; NumCpu=1; MemoryGB=1 }
        $suspended = [pscustomobject]@{ Id='vm-2'; Name='b'; VMHostId='h-1'; PowerState='Suspended'; NumCpu=1; MemoryGB=1 }

        (ConvertTo-InventoryVm -Vm $poweredOff).powerState | Should -Be 'POWERED_OFF'
        (ConvertTo-InventoryVm -Vm $suspended).powerState | Should -Be 'SUSPENDED'
    }

    It 'throws for an unrecognized power state' {
        $badVm = [pscustomobject]@{ Id='vm-3'; Name='c'; VMHostId='h-1'; PowerState='Weird'; NumCpu=1; MemoryGB=1 }

        { ConvertTo-InventoryVm -Vm $badVm } | Should -Throw "*Weird*"
    }
}

Describe 'Export-PlatformInventoryJson' {
    It 'writes a snapshot to disk as JSON matching the SyncRequest shape' {
        $snapshot = [pscustomobject]@{
            hosts      = @([pscustomobject]@{ id='h-1'; name='host'; cluster='c'; cpuCores=2; memoryMb=4096; datastoreIds=@('ds-1') })
            vms        = @([pscustomobject]@{ id='vm-1'; name='vm'; hostId='h-1'; powerState='POWERED_ON'; cpuCount=1; memoryMb=1024 })
            datastores = @([pscustomobject]@{ id='ds-1'; name='ds'; capacityGb=100; freeGb=50 })
        }
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "hpl-inventory-$([guid]::NewGuid()).json"

        try {
            $returnedPath = Export-PlatformInventoryJson -Snapshot $snapshot -Path $tempPath

            $returnedPath | Should -Be $tempPath
            Test-Path $tempPath | Should -BeTrue

            $parsed = Get-Content $tempPath -Raw | ConvertFrom-Json
            $parsed.hosts[0].id | Should -Be 'h-1'
            $parsed.vms[0].hostId | Should -Be 'h-1'
            $parsed.datastores[0].id | Should -Be 'ds-1'
        }
        finally {
            Remove-Item $tempPath -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Sync-PlatformInventory' {
    BeforeAll {
        Mock -ModuleName HybridPlatformSync Connect-VcsimEnvironment { return 'fake-connection' }
        Mock -ModuleName HybridPlatformSync Disconnect-VcsimEnvironment { }
        Mock -ModuleName HybridPlatformSync Get-PlatformInventorySnapshot {
            [pscustomobject]@{
                hosts      = @([pscustomobject]@{ id='h-1'; name='host'; cluster='c'; cpuCores=2; memoryMb=4096; datastoreIds=@() })
                vms        = @()
                datastores = @()
            }
        }
        Mock -ModuleName HybridPlatformSync Invoke-RestMethod {
            [pscustomobject]@{ hostCount = 1; vmCount = 0; datastoreCount = 0 }
        }
    }

    It 'connects, snapshots, posts to /api/v1/sync, and disconnects' {
        $credential = [pscredential]::new('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

        $result = Sync-PlatformInventory -VcsimServer '127.0.0.1' -VcsimPort 8989 -VcsimCredential $credential -ApiBaseUrl 'http://localhost:8080/'

        $result.hostCount | Should -Be 1
        Should -Invoke -ModuleName HybridPlatformSync Connect-VcsimEnvironment -Times 1
        Should -Invoke -ModuleName HybridPlatformSync Disconnect-VcsimEnvironment -Times 1
        Should -Invoke -ModuleName HybridPlatformSync Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -eq 'http://localhost:8080/api/v1/sync' -and $Method -eq 'Post'
        }
    }

    It 'disconnects even when the snapshot step throws' {
        Mock -ModuleName HybridPlatformSync Get-PlatformInventorySnapshot { throw 'snapshot failed' }
        $credential = [pscredential]::new('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

        { Sync-PlatformInventory -VcsimServer '127.0.0.1' -VcsimCredential $credential -ApiBaseUrl 'http://localhost:8080' } | Should -Throw '*snapshot failed*'

        Should -Invoke -ModuleName HybridPlatformSync Disconnect-VcsimEnvironment -Times 1
    }
}
