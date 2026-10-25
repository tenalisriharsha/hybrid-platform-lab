#Requires -Version 7.0

function Connect-VcsimEnvironment {
    <#
        .SYNOPSIS
        Connects PowerCLI to a vcsim-simulated vCenter/ESXi endpoint.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string] $Server,

        [int] $Port = 443,

        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip:$false -Confirm:$false -Scope Session | Out-Null
    Connect-VIServer -Server $Server -Port $Port -Credential $Credential -ErrorAction Stop
}

function Disconnect-VcsimEnvironment {
    <#
        .SYNOPSIS
        Disconnects a PowerCLI session previously opened with Connect-VcsimEnvironment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Connection
    )

    Disconnect-VIServer -Server $Connection -Confirm:$false
}

function ConvertTo-InventoryPowerState {
    <#
        .SYNOPSIS
        Maps a PowerCLI VM.PowerState value to platform-api's PowerState enum.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $PowerCliPowerState
    )

    switch ($PowerCliPowerState) {
        'PoweredOn' { 'POWERED_ON' }
        'PoweredOff' { 'POWERED_OFF' }
        'Suspended' { 'SUSPENDED' }
        default { throw "Unrecognized PowerCLI power state: '$PowerCliPowerState'" }
    }
}

function ConvertTo-InventoryDatastore {
    <#
        .SYNOPSIS
        Converts a PowerCLI datastore object into platform-api's Datastore JSON shape.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Datastore
    )

    [pscustomobject]@{
        id         = [string]$Datastore.Id
        name       = [string]$Datastore.Name
        capacityGb = [long][math]::Round([double]$Datastore.CapacityGB)
        freeGb     = [long][math]::Round([double]$Datastore.FreeSpaceGB)
    }
}

function ConvertTo-InventoryHost {
    <#
        .SYNOPSIS
        Converts a PowerCLI VMHost object into platform-api's Host JSON shape.

        .DESCRIPTION
        Cluster membership and attached datastores are resolved by the caller
        (via Get-Cluster / Get-Datastore -VMHost) and passed in explicitly, so
        this conversion stays a pure function that Pester can exercise with
        plain PSCustomObjects instead of a live vcsim connection.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $VMHost,

        [string] $Cluster,

        [string[]] $DatastoreIds = @()
    )

    [pscustomobject]@{
        id           = [string]$VMHost.Id
        name         = [string]$VMHost.Name
        cluster      = if ([string]::IsNullOrWhiteSpace($Cluster)) { 'standalone' } else { $Cluster }
        cpuCores     = [int]$VMHost.NumCpu
        memoryMb     = [int][math]::Round([double]$VMHost.MemoryTotalGB * 1024)
        datastoreIds = @($DatastoreIds | ForEach-Object { [string]$_ })
    }
}

function ConvertTo-InventoryVm {
    <#
        .SYNOPSIS
        Converts a PowerCLI VM object into platform-api's VirtualMachine JSON shape.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Vm
    )

    [pscustomobject]@{
        id         = [string]$Vm.Id
        name       = [string]$Vm.Name
        hostId     = [string]$Vm.VMHostId
        powerState = ConvertTo-InventoryPowerState -PowerCliPowerState ([string]$Vm.PowerState)
        cpuCount   = [int]$Vm.NumCpu
        memoryMb   = [int][math]::Round([double]$Vm.MemoryGB * 1024)
    }
}

function Get-PlatformInventorySnapshot {
    <#
        .SYNOPSIS
        Pulls hosts, VMs, and datastores out of the currently connected
        vCenter/vcsim session and shapes them for platform-api's /api/v1/sync.

        .DESCRIPTION
        Requires an active PowerCLI connection (see Connect-VcsimEnvironment).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $datastores = @(Get-Datastore | ForEach-Object { ConvertTo-InventoryDatastore -Datastore $_ })

    $hosts = @(Get-VMHost | ForEach-Object {
            $vmHost = $_
            $cluster = Get-Cluster -VMHost $vmHost -ErrorAction SilentlyContinue
            $hostDatastoreIds = @(Get-Datastore -VMHost $vmHost | ForEach-Object { $_.Id })
            ConvertTo-InventoryHost -VMHost $vmHost -Cluster $cluster.Name -DatastoreIds $hostDatastoreIds
        })

    $vms = @(Get-VM | ForEach-Object { ConvertTo-InventoryVm -Vm $_ })

    [pscustomobject]@{
        hosts      = $hosts
        vms        = $vms
        datastores = $datastores
    }
}

function Export-PlatformInventoryJson {
    <#
        .SYNOPSIS
        Writes an inventory snapshot to a JSON file matching platform-api's SyncRequest shape.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Snapshot,

        [Parameter(Mandatory)]
        [string] $Path
    )

    ($Snapshot | ConvertTo-Json -Depth 6) | Set-Content -Path $Path -Encoding utf8
    return $Path
}

function Sync-PlatformInventory {
    <#
        .SYNOPSIS
        Connects to vcsim, snapshots its inventory, and posts it to platform-api's /api/v1/sync.

        .DESCRIPTION
        End-to-end entry point: open a PowerCLI session against vcsim, convert
        its hosts/VMs/datastores to platform-api's JSON shape, POST that
        snapshot to the control-plane API, then disconnect.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $VcsimServer,

        [int] $VcsimPort = 8989,

        [Parameter(Mandatory)]
        [pscredential] $VcsimCredential,

        [Parameter(Mandatory)]
        [string] $ApiBaseUrl
    )

    $connection = Connect-VcsimEnvironment -Server $VcsimServer -Port $VcsimPort -Credential $VcsimCredential
    try {
        $snapshot = Get-PlatformInventorySnapshot
    }
    finally {
        Disconnect-VcsimEnvironment -Connection $connection
    }

    $body = $snapshot | ConvertTo-Json -Depth 6
    $syncUri = '{0}/api/v1/sync' -f $ApiBaseUrl.TrimEnd('/')
    Invoke-RestMethod -Method Post -Uri $syncUri -ContentType 'application/json' -Body $body
}

Export-ModuleMember -Function @(
    'Connect-VcsimEnvironment',
    'Disconnect-VcsimEnvironment',
    'ConvertTo-InventoryDatastore',
    'ConvertTo-InventoryHost',
    'ConvertTo-InventoryVm',
    'Get-PlatformInventorySnapshot',
    'Export-PlatformInventoryJson',
    'Sync-PlatformInventory'
)
