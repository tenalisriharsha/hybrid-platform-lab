# Daily Report

A summary of what was built across this project's full build cycle, the
final test results, known limitations, and ideas for future work. For the
phase-by-phase build history and the design notes accumulated along the
way, see [PROGRESS.md](PROGRESS.md).

## What was built

**FastAPI self-service API** (`api/`) - `POST`/`GET`/`DELETE /environments`
validated against a fixed catalog of templates and sizes, owner (email) and
`ttl_hours` (1-168h) fields with a server-computed `expiry`, a `/metrics`
endpoint exposing Prometheus counters/histograms/gauges from a
per-app-instance registry, and a `/healthz` liveness check. The API never
provisions anything itself - it derives a backend from the requested
template and delegates to one of three real backend implementations, each
falling back to a simulated backend when its environment isn't configured,
so the API stays usable with zero external dependencies on hand.

**vSphere backend** (`api/app/backends/vsphere.py` + `powercli/`) - a
three-cmdlet PowerCLI module (`New-LabVM`, `Get-VMInventoryReport`,
`Invoke-SnapshotPolicy`) that the API drives through `pwsh`, tested with
Pester against a real [vcsim](https://github.com/vmware/govmomi/tree/main/vcsim)
container in both vCenter and standalone-ESXi mode. Owner/expiry/protected
markers use vSphere tags when available and fall back to a `Notes` string
marker when they aren't (vcsim's vCenter simulation never supports tags -
documented, not glossed over). The password is read from an environment
variable by the PowerShell script itself, never passed as a CLI argument.

**Proxmox and Azure backends** (`api/app/backends/{proxmox,azure}.py` +
`terraform/`) - two Terraform modules (`modules/proxmox-vm` via
`bpg/proxmox`, `modules/azure-vm` via `azurerm`), each with its own
`terraform test` suite using `mock_provider`, plus `dev` (ungated) and
`validation` (approval-gated, a `terraform plan` refuses to proceed until
`approved = true`) environment folders. The API backends render a `tfvars`
file from the request and run `terraform plan` - **never `apply`** - against
`dev`.

**Host baselines** (`ansible/` + `windows/`) - an Ansible `linux-baseline`
role (admin user, SSH hardening, packages, `node_exporter`) proven
idempotent by applying it twice to a disposable Docker container and
asserting the second run is a no-op, and a `WindowsBaseline` PowerShell
module (`Invoke-WindowsBaseline`, services/features/firewall compliance and
remediation with full `-WhatIf`/`-Confirm` support) unit tested with every
Windows-only cmdlet mocked, since this project is developed on macOS.

**CI and docs** - one GitHub Actions workflow (`.github/workflows/ci.yml`)
with five independent jobs (`api`, `pester-vcsim`, `terraform`, `ansible`,
`windows-pester`), `RUNBOOK.md` (failed provisioning, exhausted capacity,
rollback, a failed CI job), and `docs/modernization.md` (a decision table
for which workloads stay on VMware versus move to containers or Azure).

**Previews** (`docs/screenshots/`, `scripts/capture/`) - eleven screenshots,
every one a real, captured run: the Swagger UI, a live create/list round
trip, the pytest suite, `ruff check`, the live `/metrics` endpoint, the
Pester suite against vcsim, a real drift report, `Invoke-SnapshotPolicy
-WhatIf` refusing a protected VM, `terraform test`, and `ansible-lint` plus
the idempotence check. `scripts/capture/capture-screenshots.mjs` regenerates
the last two by actually running `terraform test` and
`./scripts/run-ansible-tests.sh` and screenshotting their genuine output.

## Test results (final run)

| Suite | Command | Result |
|---|---|---|
| API (pytest) | `cd api && python -m pytest -v` | **54 passed** (includes 2 live tests: a real vcsim provision/deprovision round trip, a real `terraform init`+`plan` against the Proxmox dev environment) |
| Lint (ruff) | `cd api && ruff check .` | **Clean** |
| PowerCLI (Pester vs. vcsim) | `./scripts/run-pester-tests.sh` | **35 passed** (vCenter + standalone-ESXi modes, ~268s) |
| PowerCLI unit tests (mock-only) | `Invoke-Pester powercli/Tests/LabMarker.Tests.ps1` | **7 passed** (included in the 35 above) |
| Terraform | `terraform fmt -check`, `terraform validate`, `terraform test` across all 6 module/environment folders | **fmt/validate clean on all 6; 16/16 `terraform test` runs passed** |
| Ansible | `./scripts/run-ansible-tests.sh` | **`ansible-lint`: 0 failures, 0 warnings; idempotence confirmed (`changed=0` on the second apply)** |
| WindowsBaseline (Pester, mocked) | `Invoke-Pester windows/Tests` | **10 passed** |

Every number above comes from a genuine local run on this machine on the
day this report was written - nothing is estimated or copied from an
earlier session. The one job never run locally is `windows-pester` in CI
(there's no Windows host here); it mirrors the same mocked assertions and
is the first real proof the module's Windows-only cmdlet wrappers load on
an actual Windows host once this pushes to GitHub.

## Known limitations

- **Nothing here provisions real infrastructure.** The vSphere backend only
  ever touches vcsim; the Proxmox/Azure backends only ever run
  `terraform plan`. This is a deliberate scope boundary for a lab, stated
  plainly in the README, not an oversight.
- **vcsim doesn't simulate vSphere tags or custom attributes in every
  mode** - confirmed by hand during Phase 2, documented in
  `powercli/README.md`, and worked around with a `Notes`-marker fallback
  that's real code, not a test-only stub. A real vCenter with the Lookup
  Service available will use tags, as `LabMarkerTags.ps1` implements -
  that code path is simply never exercised against vcsim.
- **No quota or capacity layer.** `Get-VMInventoryReport` and
  `Invoke-SnapshotPolicy` exist for operational visibility and cleanup;
  there's no admission control stopping the catalog from being requested
  past whatever capacity actually exists. See `RUNBOOK.md`'s "exhausted
  capacity" section for what exists today versus what doesn't.
- **The Windows CI job is unverified by this machine, by design** - it can
  only be proven by GitHub's `windows-latest` runner once this is pushed.
- **No automated migration tooling.** `docs/modernization.md` is a decision
  table for where a workload *should* live, not a tool that moves it there.

## Ideas for future work

- A real admission-control/quota layer in front of `POST /environments`,
  using the inventory data `Get-VMInventoryReport` already collects.
- A `windows-baseline` Ansible-equivalent playbook wrapper so Windows hosts
  can be driven from the same CI/orchestration surface as Linux ones,
  rather than requiring a direct PowerShell/PowerCLI session.
- Extending the Proxmox/Azure backends past `plan` into a gated `apply`
  path once a real non-lab environment exists to point them at, reusing the
  `validation` environment folders' approval-gate pattern.
- A small web UI over the existing API (the API itself is UI-agnostic by
  design) for owners who would rather not use `curl`/Swagger directly.
