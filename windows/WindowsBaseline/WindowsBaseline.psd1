@{
    RootModule        = 'WindowsBaseline.psm1'
    ModuleVersion      = '0.1.0'
    GUID               = 'f3c9d6a0-5b1e-4d7a-8c2a-9e4b6f0a1d3c'
    Author             = 'tenalisriharsha'
    Description        = 'Checks and optionally remediates the hybrid platform lab Windows Server baseline: services, Windows features and firewall profiles.'
    PowerShellVersion  = '7.0'
    FunctionsToExport  = @('Invoke-WindowsBaseline')
    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}
