# Shared helpers for the Pester suite. Requires a running vcsim container per mode
# (see scripts/run-pester-tests.sh); these tests never touch real vSphere.

function Connect-HybridLabTestServer {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)] [ValidateSet('vCenter', 'ESXi')] [string] $Mode
    )

    $port = if ($Mode -eq 'vCenter') {
        if ($env:HPL_VCSIM_VCENTER_PORT) { $env:HPL_VCSIM_VCENTER_PORT } else { '8989' }
    }
    else {
        if ($env:HPL_VCSIM_ESXI_PORT) { $env:HPL_VCSIM_ESXI_PORT } else { '8990' }
    }

    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false -Scope Session -Confirm:$false | Out-Null
    Connect-VIServer -Server '127.0.0.1' -Port $port -User 'user' -Password 'pass' -Force
}
