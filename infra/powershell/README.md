# HybridPlatformSync

A PowerCLI module that connects to the `vcsim` simulated vCenter, enumerates
hosts, VMs, and datastores, and syncs them into `platform-api` via
`POST /api/v1/sync`.

## Layout

```
HybridPlatformSync/
  HybridPlatformSync.psd1   Module manifest
  HybridPlatformSync.psm1   Module implementation
Tests/
  HybridPlatformSync.Tests.ps1   Pester tests (no live vcsim/API needed)
Run-Tests.ps1               Runs PSScriptAnalyzer + Pester together
```

## Functions

| Function | Purpose |
|---|---|
| `Connect-VcsimEnvironment` / `Disconnect-VcsimEnvironment` | Open/close a PowerCLI session against vcsim, ignoring its self-signed cert |
| `ConvertTo-InventoryDatastore` / `ConvertTo-InventoryHost` / `ConvertTo-InventoryVm` | Pure conversions from PowerCLI objects to `platform-api`'s JSON shape |
| `Get-PlatformInventorySnapshot` | Pulls the full hosts/VMs/datastores estate from the active connection |
| `Export-PlatformInventoryJson` | Writes a snapshot to a JSON file (useful for inspection without a live API) |
| `Sync-PlatformInventory` | End-to-end: connect, snapshot, POST to `platform-api`, disconnect |

## Usage

```powershell
Import-Module ./HybridPlatformSync/HybridPlatformSync.psd1

$cred = [pscredential]::new('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
Sync-PlatformInventory -VcsimServer 127.0.0.1 -VcsimPort 8989 `
    -VcsimCredential $cred -ApiBaseUrl 'http://localhost:8080'
```

`vcsim`'s default credentials are `user` / `pass` (see its container logs —
`vmware/vcsim` prints `GOVC_URL=https://user:pass@<ip>:8989/sdk` on start).

## Testing

```powershell
pwsh -NoProfile -File ./Run-Tests.ps1
```

Runs a clean `PSScriptAnalyzer` pass and the Pester suite. The Pester tests
exercise the conversion functions and `Sync-PlatformInventory`'s
connect/snapshot/post/disconnect flow entirely with mocked PowerCLI objects
and cmdlets — no live vcsim connection required.

For a real end-to-end check against live containers, run
`../../scripts/integration-test-sync.sh` from the repo root: it boots
`vcsim` and `platform-api` via `docker compose`, runs `Sync-PlatformInventory`
against them, asserts the API's inventory now reflects vcsim's estate, and
tears both containers down.
