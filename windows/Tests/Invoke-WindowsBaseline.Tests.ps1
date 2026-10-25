# Pure unit tests for Invoke-WindowsBaseline, with every Windows-only cmdlet mocked via the
# module's thin wrappers (Get-BaselineServiceState, Get-BaselineFeatureState, ...). These run
# on any OS/pwsh 7 host - they are what CI's non-Windows jobs could run too, though the real
# proof this logic matches real Windows behaviour is the windows-latest Pester job, which
# calls the same wrappers against real Get-Service/Get-WindowsFeature/Get-NetFirewallProfile.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'WindowsBaseline') -Force
}

Describe 'Invoke-WindowsBaseline services' {
    It 'reports a compliant service as compliant and does not remediate' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineServiceState {
                [PSCustomObject]@{ Status = 'Running'; StartType = 'Automatic' }
            }
            Mock Set-BaselineServiceState { }

            $report = Invoke-WindowsBaseline -DesiredServices @{ WinRM = @{ Status = 'Running'; StartupType = 'Automatic' } } `
                -DesiredFeatures @() -FirewallProfiles @()

            $report.Compliant | Should -BeTrue
            $report.Results[0].Compliant | Should -BeTrue
            $report.Results[0].Remediated | Should -BeFalse
            Should -Invoke Set-BaselineServiceState -Times 0
        }
    }

    It 'reports a drifted service as non-compliant and does not remediate without -Remediate' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineServiceState {
                [PSCustomObject]@{ Status = 'Stopped'; StartType = 'Disabled' }
            }
            Mock Set-BaselineServiceState { }

            $report = Invoke-WindowsBaseline -DesiredServices @{ WinRM = @{ Status = 'Running'; StartupType = 'Automatic' } } `
                -DesiredFeatures @() -FirewallProfiles @()

            $report.Compliant | Should -BeFalse
            $report.Results[0].Compliant | Should -BeFalse
            Should -Invoke Set-BaselineServiceState -Times 0
        }
    }

    It 'remediates a drifted service when -Remediate is passed' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineServiceState {
                [PSCustomObject]@{ Status = 'Stopped'; StartType = 'Disabled' }
            }
            Mock Set-BaselineServiceState { }

            $report = Invoke-WindowsBaseline -DesiredServices @{ WinRM = @{ Status = 'Running'; StartupType = 'Automatic' } } `
                -DesiredFeatures @() -FirewallProfiles @() -Remediate -Confirm:$false

            $report.Results[0].Remediated | Should -BeTrue
            $report.Results[0].Compliant | Should -BeTrue
            Should -Invoke Set-BaselineServiceState -Times 1 -ParameterFilter {
                $Name -eq 'WinRM' -and $Status -eq 'Running' -and $StartupType -eq 'Automatic'
            }
        }
    }

    It 'does not remediate under -WhatIf' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineServiceState {
                [PSCustomObject]@{ Status = 'Stopped'; StartType = 'Disabled' }
            }
            Mock Set-BaselineServiceState { }

            $report = Invoke-WindowsBaseline -DesiredServices @{ WinRM = @{ Status = 'Running'; StartupType = 'Automatic' } } `
                -DesiredFeatures @() -FirewallProfiles @() -Remediate -WhatIf

            $report.Results[0].Remediated | Should -BeFalse
            Should -Invoke Set-BaselineServiceState -Times 0
        }
    }

    It 'reports a missing service as non-compliant without throwing' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineServiceState { $null }

            $report = Invoke-WindowsBaseline -DesiredServices @{ GhostSvc = @{ Status = 'Running'; StartupType = 'Automatic' } } `
                -DesiredFeatures @() -FirewallProfiles @()

            $report.Results[0].Actual | Should -Be 'NotFound'
            $report.Results[0].Compliant | Should -BeFalse
        }
    }
}

Describe 'Invoke-WindowsBaseline features' {
    It 'reports an installed feature as compliant' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineFeatureState { [PSCustomObject]@{ Installed = $true } }
            Mock Install-BaselineFeature { }

            $report = Invoke-WindowsBaseline -DesiredServices @{} -DesiredFeatures @('Web-Server') -FirewallProfiles @()

            $report.Results[0].Compliant | Should -BeTrue
            Should -Invoke Install-BaselineFeature -Times 0
        }
    }

    It 'installs a missing feature when -Remediate is passed' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineFeatureState { [PSCustomObject]@{ Installed = $false } }
            Mock Install-BaselineFeature { }

            $report = Invoke-WindowsBaseline -DesiredServices @{} -DesiredFeatures @('Web-Server') -FirewallProfiles @() `
                -Remediate -Confirm:$false

            $report.Results[0].Remediated | Should -BeTrue
            $report.Results[0].Compliant | Should -BeTrue
            Should -Invoke Install-BaselineFeature -Times 1 -ParameterFilter { $Name -eq 'Web-Server' }
        }
    }
}

Describe 'Invoke-WindowsBaseline firewall' {
    It 'reports a disabled firewall profile as non-compliant' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineFirewallProfile { [PSCustomObject]@{ Enabled = $false } }

            $report = Invoke-WindowsBaseline -DesiredServices @{} -DesiredFeatures @() -FirewallProfiles @('Public')

            $report.Compliant | Should -BeFalse
            $report.Results[0].Actual | Should -Be 'Disabled'
        }
    }

    It 'enables a disabled firewall profile when -Remediate is passed' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineFirewallProfile { [PSCustomObject]@{ Enabled = $false } }
            Mock Enable-BaselineFirewallProfile { }

            $report = Invoke-WindowsBaseline -DesiredServices @{} -DesiredFeatures @() -FirewallProfiles @('Public') `
                -Remediate -Confirm:$false

            $report.Results[0].Remediated | Should -BeTrue
            Should -Invoke Enable-BaselineFirewallProfile -Times 1 -ParameterFilter { $Name -eq 'Public' }
        }
    }
}

Describe 'Invoke-WindowsBaseline overall compliance' {
    It 'is only compliant when every check (service, feature, firewall) is compliant' {
        InModuleScope WindowsBaseline {
            Mock Get-BaselineServiceState { [PSCustomObject]@{ Status = 'Running'; StartType = 'Automatic' } }
            Mock Get-BaselineFeatureState { [PSCustomObject]@{ Installed = $true } }
            Mock Get-BaselineFirewallProfile { [PSCustomObject]@{ Enabled = $false } }

            $report = Invoke-WindowsBaseline -DesiredServices @{ WinRM = @{ Status = 'Running'; StartupType = 'Automatic' } } `
                -DesiredFeatures @('Web-Server') -FirewallProfiles @('Public')

            $report.Compliant | Should -BeFalse
            ($report.Results | Where-Object { $_.Type -eq 'Firewall' }).Compliant | Should -BeFalse
        }
    }
}
