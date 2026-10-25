@{
    RootModule        = 'HybridLab.psm1'
    ModuleVersion      = '0.1.0'
    GUID               = 'b4a1e8d2-7c3a-4e4a-9f0e-3a7e6b1d5c2f'
    Author             = 'tenalisriharsha'
    Description        = 'VM lifecycle cmdlets for the hybrid platform lab vSphere backend: clone VMs, report inventory and drift, and apply a snapshot lifecycle policy.'
    PowerShellVersion  = '7.0'
    FunctionsToExport  = @('New-LabVM', 'Get-VMInventoryReport', 'Invoke-SnapshotPolicy')
    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}
