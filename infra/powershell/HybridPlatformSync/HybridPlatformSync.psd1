@{
    RootModule        = 'HybridPlatformSync.psm1'
    ModuleVersion      = '0.1.0'
    GUID               = 'b3f1c9a4-6b2a-4e2e-9a5e-6f6c2c0b9c11'
    Author             = 'Hybrid Platform Lab'
    Description        = 'Pulls live inventory out of a vcsim-simulated vCenter via PowerCLI and syncs it into the platform-api control plane.'
    PowerShellVersion  = '7.0'
    RequiredModules    = @()
    FunctionsToExport  = @(
        'Connect-VcsimEnvironment',
        'Disconnect-VcsimEnvironment',
        'ConvertTo-InventoryDatastore',
        'ConvertTo-InventoryHost',
        'ConvertTo-InventoryVm',
        'Get-PlatformInventorySnapshot',
        'Export-PlatformInventoryJson',
        'Sync-PlatformInventory'
    )
    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}
