# WindowsBaseline PowerShell module

One cmdlet, `Invoke-WindowsBaseline`, checking (and, with `-Remediate`,
fixing) the hybrid-platform-lab Windows Server baseline: service state and
startup type, installed Windows features, and enabled firewall profiles.

```powershell
Import-Module ./WindowsBaseline -Force

# Check only - nothing changes.
Invoke-WindowsBaseline -DesiredFeatures 'Web-Server'

# Preview what remediation would do, without doing it.
Invoke-WindowsBaseline -DesiredFeatures 'Web-Server' -Remediate -WhatIf

# Actually remediate.
Invoke-WindowsBaseline -DesiredFeatures 'Web-Server' -Remediate -Confirm:$false
```

Returns a `PSCustomObject` with an overall `Compliant` flag and a `Results`
array - one row per service/feature/firewall-profile checked, each with
`Expected`, `Actual`, `Compliant` and `Remediated`.

## Why every Windows-only cmdlet is wrapped

`Get-Service`, `Get-WindowsFeature` and `Get-NetFirewallProfile` (and their
state-changing counterparts) don't exist outside Windows, so they can't be
mocked directly by Pester on a non-Windows development machine - there's no
real command there to intercept. `Invoke-WindowsBaseline` never calls them
itself; it calls a thin same-module wrapper per cmdlet
(`Get-BaselineServiceState`, `Install-BaselineFeature`, ...), and the Pester
suite mocks those wrappers instead. The wrappers themselves are one line
each, so what's actually unit-tested is 100% of the orchestration logic
(compliance comparison, when remediation runs, `-WhatIf`/`-Confirm`
handling) - the same pattern used for `Set-VM`/`New-TagCategory` in the
[`powercli`](../powercli) module. Those thin wrappers are not themselves
unit-testable without real Windows cmdlets; that's exactly what the
`windows-latest` CI job is for - it calls the same module for real.

## Tests

```bash
pwsh -Command "Invoke-Pester -Path ./windows/Tests"
```

Runs on macOS/Linux - every Windows-only cmdlet is mocked. This repository's
own CI additionally runs the same Pester suite on GitHub's `windows-latest`
runner; that job is the one that proves the wrappers' one line of real
cmdlet code is correct, since it cannot run here.

## Layout

```
WindowsBaseline/
  WindowsBaseline.psd1 / .psm1   module manifest + loader
  Public/                          Invoke-WindowsBaseline.ps1
  Private/                         thin wrappers around Get-Service, Get-WindowsFeature, Get-NetFirewallProfile
Tests/                             Pester suite (mocks every wrapper)
```
