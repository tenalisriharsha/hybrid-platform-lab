function Invoke-WindowsBaseline {
    <#
        .SYNOPSIS
        Checks the hybrid platform lab Windows Server baseline (services, Windows features,
        firewall profiles) and, with -Remediate, fixes whatever is out of compliance.

        .DESCRIPTION
        Read-only by default: every check runs and is reported, nothing is changed unless
        -Remediate is also passed. Remediation goes through ShouldProcess, so -WhatIf shows
        exactly what would change without changing it, and -Confirm prompts per action.

        .PARAMETER DesiredServices
        A hashtable of service name to @{ Status = 'Running'|'Stopped'; StartupType = '...' }.

        .PARAMETER DesiredFeatures
        Windows feature names (as accepted by Get-WindowsFeature) that must be installed.

        .PARAMETER FirewallProfiles
        Firewall profile names that must be enabled.

        .EXAMPLE
        Invoke-WindowsBaseline -DesiredFeatures 'Web-Server' -Remediate -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [hashtable] $DesiredServices = @{
            'W32Time' = @{ Status = 'Running'; StartupType = 'Automatic' }
            'WinRM'   = @{ Status = 'Running'; StartupType = 'Automatic' }
        },
        [string[]] $DesiredFeatures = @(),
        [string[]] $FirewallProfiles = @('Domain', 'Private', 'Public'),
        [switch] $Remediate
    )

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($name in $DesiredServices.Keys) {
        $desired = $DesiredServices[$name]
        $service = Get-BaselineServiceState -Name $name

        if (-not $service) {
            $results.Add([PSCustomObject]@{
                Type = 'Service'; Name = $name
                Expected = "$($desired.Status)/$($desired.StartupType)"; Actual = 'NotFound'
                Compliant = $false; Remediated = $false
            })
            continue
        }

        $compliant = ($service.Status.ToString() -eq $desired.Status) -and
            ($service.StartType.ToString() -eq $desired.StartupType)
        $remediated = $false

        if (-not $compliant -and $Remediate) {
            if ($PSCmdlet.ShouldProcess($name, "Set service to $($desired.Status)/$($desired.StartupType)")) {
                Set-BaselineServiceState -Name $name -Status $desired.Status -StartupType $desired.StartupType
                $remediated = $true
                $compliant = $true
            }
        }

        $results.Add([PSCustomObject]@{
            Type = 'Service'; Name = $name
            Expected = "$($desired.Status)/$($desired.StartupType)"
            Actual = "$($service.Status)/$($service.StartType)"
            Compliant = $compliant; Remediated = $remediated
        })
    }

    foreach ($name in $DesiredFeatures) {
        $feature = Get-BaselineFeatureState -Name $name
        $installed = [bool]($feature -and $feature.Installed)
        $remediated = $false

        if (-not $installed -and $Remediate) {
            if ($PSCmdlet.ShouldProcess($name, 'Install Windows feature')) {
                Install-BaselineFeature -Name $name
                $remediated = $true
                $installed = $true
            }
        }

        $results.Add([PSCustomObject]@{
            Type = 'Feature'; Name = $name
            Expected = 'Installed'; Actual = $(if ($installed) { 'Installed' } else { 'Absent' })
            Compliant = $installed; Remediated = $remediated
        })
    }

    foreach ($name in $FirewallProfiles) {
        $fwProfile = Get-BaselineFirewallProfile -Name $name
        $enabled = [bool]($fwProfile -and $fwProfile.Enabled)
        $remediated = $false

        if (-not $enabled -and $Remediate) {
            if ($PSCmdlet.ShouldProcess($name, 'Enable firewall profile')) {
                Enable-BaselineFirewallProfile -Name $name
                $remediated = $true
                $enabled = $true
            }
        }

        $results.Add([PSCustomObject]@{
            Type = 'Firewall'; Name = $name
            Expected = 'Enabled'; Actual = $(if ($enabled) { 'Enabled' } else { 'Disabled' })
            Compliant = $enabled; Remediated = $remediated
        })
    }

    [PSCustomObject]@{
        Timestamp = Get-Date
        Compliant = -not [bool]($results | Where-Object { -not $_.Compliant })
        Results   = $results.ToArray()
    }
}
