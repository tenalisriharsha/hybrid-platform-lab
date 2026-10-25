# HybridLab PowerCLI module

Three cmdlets for managing lab VMs on vSphere: `New-LabVM`, `Get-VMInventoryReport`
and `Invoke-SnapshotPolicy`. Requires PowerShell 7+ and
[VMware.PowerCLI](https://developer.vmware.com/powercli), and an active
`Connect-VIServer` session (the cmdlets operate on the current connection,
same as the rest of PowerCLI).

```powershell
Import-Module ./HybridLab -Force
Connect-VIServer -Server vcenter.example.com -User ... -Password ...

New-LabVM -TemplateName 'tpl-ubuntu-2204' -Name 'dev-box-1' `
    -VMHost (Get-VMHost | Select-Object -First 1) -PortGroup 'VM Network' `
    -Owner 'alice@example.com' -Expiry '2026-11-08T00:00:00Z'

Get-VMInventoryReport -DesiredStatePath ./examples/desired-state.sample.json -NamePattern 'lab-*'

Get-VM -Name 'lab-*' | Invoke-SnapshotPolicy -CreateSnapshot -RetentionDays 7 -WhatIf
```

## Cmdlets

- **`New-LabVM`** - clones a VM from a template, optionally attaches a port
  group, and marks it with `-Owner`, `-Expiry` (an ISO 8601 string) and
  `-Protected`. Supports `-WhatIf`/`-Confirm`.
- **`Get-VMInventoryReport`** - lists the current VM inventory (including
  each VM's owner/expiry/protected marker) and, given `-DesiredStatePath` (a
  JSON file, see `examples/desired-state.sample.json`), reports drift:
  `Missing` (expected but absent), `Mismatch` (PowerState/NumCpu/MemoryGB
  differs) and, when `-NamePattern` is also given, `Unexpected` (present,
  matches the pattern, not in the desired state).
- **`Invoke-SnapshotPolicy`** - optionally creates a new snapshot per VM,
  then prunes snapshots older than `-RetentionDays` (default 7). Refuses to
  touch any VM marked `-Protected` - skips it with a warning rather than
  erroring, so a mixed batch still completes. Supports `-WhatIf`/`-Confirm`.

## The owner/expiry/protected marker

Markers are written directly onto the VM so they survive outside this
module's own state: as vSphere **tags** (one category per field) when the
connected server supports them, or as a single-line **VM Notes** marker
(`hybridlab:v1|owner=...|expiry=...|protected=...`) otherwise. `-MarkerStrategy`
on `New-LabVM` controls this (`Auto` by default; `Tag` or `Notes` to force
one). `Auto` only attempts tags on a vCenter connection, and falls back to
Notes automatically if that attempt fails.

vcsim's vCenter simulation does not implement the Lookup Service that
vSphere tagging depends on, so **the tag path is never exercised against
vcsim** - every Pester test against vcsim takes the Notes fallback, and that
fallback is exactly what's being tested. The tag code path itself is
unit-tested with mocks in `Tests/LabMarker.Tests.ps1`; only a real vCenter
proves it end to end. Don't read a passing vcsim run as proof that tagging
itself works.

## Tests

```bash
./scripts/run-pester-tests.sh   # from the repo root
```

Starts a vcsim container in vCenter mode and one in standalone-ESXi mode
(Docker required), runs the full Pester suite against both, and tears the
containers down afterwards. `Tests/LabMarker.Tests.ps1` needs neither vcsim
nor Docker - it's a pure mock-based unit test and runs in well under a
second on its own:

```bash
pwsh -Command "Invoke-Pester -Path ./powercli/Tests/LabMarker.Tests.ps1"
```

## Layout

```
HybridLab/
  HybridLab.psd1 / .psm1   module manifest + loader
  Public/                   New-LabVM.ps1, Get-VMInventoryReport.ps1, Invoke-SnapshotPolicy.ps1
  Private/                  the owner/expiry/protected marker abstraction (tags vs. Notes)
scripts/                    pwsh entry points the API's vSphere backend (api/app/backends/vsphere.py) shells out to
Tests/                      Pester suite
examples/                   a sample desired-state.json for Get-VMInventoryReport
```
