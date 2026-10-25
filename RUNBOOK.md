# Runbook

Operational procedures for Hybrid Platform Lab. This covers what to do when
something goes wrong with the API, a backend, or the automation that runs
against a provisioned VM. It assumes familiarity with the architecture in
[README.md](README.md).

## Failed provisioning (`POST /environments` returns an error)

`POST /environments` returns:

- **400/422** - the request itself was invalid (unknown template/size, bad
  owner email, `ttl_hours` out of range). Nothing was provisioned. Fix the
  request; no cleanup needed. This is the common case - the catalog
  (`GET /catalog`) is the single source of truth for what's valid, so check
  it first if a template/size that "should" exist is being rejected.
- **502** - the request was valid but the backend itself failed
  (`ProvisioningError`). The environment record is **not** created; nothing
  was left running. The response `detail` carries the backend's own error
  text (PowerCLI's error message, or terraform's stderr), which is almost
  always enough to diagnose directly:

  | Symptom in `detail` | Likely cause | Action |
  |---|---|---|
  | `Connect-VIServer` timeout/refused | vCenter/ESXi unreachable, or `HYBRID_LAB_VSPHERE_SERVER`/`_PORT` wrong | Check network path and the env vars the API process was started with. |
  | `Could not find VM with name '<source_vm>'` | The catalog's `source_vm` placeholder doesn't match a real template VM in this vCenter | Set `HYBRID_LAB_VSPHERE_TEMPLATE_OVERRIDES` to the real template VM name, or fix `source_vm` in `api/app/catalog.py`. |
  | `HYBRID_LAB_VSPHERE_PASSWORD is not set` | The API process doesn't have the password in its environment | Set it on the process, not in a config file; it's deliberately never passed as a CLI argument. |
  | `terraform init` or `plan` error mentioning auth/401/403 | Proxmox API token or Azure service principal credentials are wrong or expired | Rotate the credential, re-set the matching `HYBRID_LAB_*` env var, restart the API process. |
  | `terraform` error mentioning a provider version/lock mismatch | `.terraform.lock.hcl` is stale against a newer module requirement | Run `terraform init -upgrade` in the affected `terraform/environments/{dev,validation}/<backend>` folder. |
  | pwsh/terraform binary not found | `pwsh` or `terraform` isn't on the API process's `PATH` | Install it, or point the API's `subprocess` calls at it (see `HYBRID_LAB_VSPHERE_MODULE_PATH` and the `app/backends/*.py` modules for where the binary is invoked). |

  If `detail` doesn't match anything above, reproduce by hand: run the exact
  PowerCLI script (`pwsh -File powercli/scripts/Invoke-VSphereProvision.ps1 ...`)
  or `terraform plan` with the same inputs outside the API, where the full
  output isn't truncated into a JSON field.

## Exhausted capacity

Nothing in this repository enforces a capacity quota today - the catalog
(`api/app/catalog.py`) defines what's *approved*, not how much of it exists.
Capacity exhaustion shows up as a backend-specific failure, caught the same
way as any other provisioning failure:

- **vSphere** - `New-LabVM`'s clone fails with vSphere's own
  insufficient-resources error (e.g. no datastore with enough free space, or
  the target cluster is at its VM-count/memory limit). This surfaces as a 502
  with that error in `detail`. There's no retry or queueing - the caller
  needs to pick a smaller `size`, a different template, or wait for capacity
  to free up (expired environments calling `DELETE` on their own, or an
  operator running `Invoke-SnapshotPolicy`/`Get-VMInventoryReport` to find
  and reclaim stale VMs).
- **Proxmox/Azure** - `terraform plan` genuinely never contacts the real API
  during a plan for a *new* resource (nothing exists yet to refresh against -
  see `PROGRESS.md`'s Phase 3 notes), so a plan-level capacity check is not
  possible here by design: these backends only ever plan, never apply, so
  capacity is checked by the operator who actually runs `terraform apply`
  outside this repository, against the plan this API produced.
- **Mitigation available today**: run `Get-VMInventoryReport` against the
  desired-state file regularly (see `powercli/README.md`) to catch VMs that
  exist but shouldn't (`Unexpected`), and `Invoke-SnapshotPolicy -WhatIf`
  before any real prune, to reclaim snapshot storage without surprises.
- **Not yet built**: a capacity reservation/quota layer in the API itself.
  If this becomes a recurring problem, it belongs as a new check in
  `api/app/routers/environments.py` before the backend is called at all -
  see "Future ideas" in `DAILY_REPORT.md`.

## Rollback

- **A bad `POST /environments` that did provision something** - call
  `DELETE /environments/{id}` with the same ID. This calls the backend's
  `deprovision()`:
  - vSphere: actually removes the cloned VM via `Remove-VM` through the same
    `pwsh` path provisioning used.
  - Proxmox/Azure: a deliberate no-op - since `provision()` only ever ran
    `terraform plan`, there is no real resource behind `backend_ref` to tear
    down. The environment record is still marked `deleted` for the audit
    trail.
  - If `deprovision()` itself fails, the API returns 502 and the environment
    record is **not** marked deleted - retry the `DELETE`, or deal with the
    backend directly (e.g. manually remove a vSphere VM) and then mark the
    record deleted by deleting it again once the underlying issue is fixed.
- **A bad Terraform module/environment change** - this repository never runs
  `terraform apply`, so there is no state to roll back here. If a change to
  `terraform/modules/*` or `terraform/environments/*` produces a bad plan,
  revert the commit; nothing was ever applied, so there is nothing live to
  undo.
- **A bad Ansible baseline run against a real host** - the `linux-baseline`
  role is designed to be safe to re-apply (every task is idempotent by
  construction, which is exactly what `scripts/run-ansible-tests.sh` checks
  in CI). Rolling back a specific change means reverting the role change and
  re-running the playbook against the affected hosts, not restoring a
  snapshot.
- **A bad Windows baseline run** - `Invoke-WindowsBaseline -Remediate` only
  changes what it's told to via `-DesiredServices`/`-DesiredFeatures`/
  `-FirewallProfiles`; nothing it does is destructive (it starts/stops
  services, installs features, enables firewall profiles - it never deletes
  data). Roll back by re-running it with the previous desired-state
  parameters, or by snapshotting the VM before running it with `-Remediate`
  for the first time against a given host.

## A failed automation job (CI)

The GitHub Actions workflow (`.github/workflows/ci.yml`) has five independent
jobs. Each one failing points at a specific, narrow area:

| Job | What failing it means | First thing to check |
|---|---|---|
| `api` (pytest + ruff) | A Python regression, or a ruff lint violation | Run `cd api && pytest -v` and `ruff check .` locally; the two live tests in this job (`test_vsphere_backend_live.py`, `test_terraform_backends_live.py`) need Docker, `pwsh` with `VMware.PowerCLI` installed, and `terraform` on `PATH` - if only those fail locally, check those tools are present before assuming the code is broken. |
| `pester-vcsim` | A PowerCLI module regression, or vcsim itself failing to start | Run `./scripts/run-pester-tests.sh` locally. vcsim's `Connect-VIServer` can genuinely take 30-90s under emulation (not an issue on CI's native x86_64 runners) - a timeout failure there before any test runs points at Docker/networking, not the module. |
| `terraform` | A module/environment regression, a formatting violation, or a provider schema change breaking a `terraform test` assertion | Run `terraform fmt -recursive -check -diff terraform`, then `terraform -chdir=<dir> validate` and `terraform -chdir=<dir> test` for the specific module/environment named in the failing step. |
| `ansible` | A role regression, an `ansible-lint` violation, or a genuine idempotence break (second apply reports `changed>0`) | Run `./scripts/run-ansible-tests.sh` locally; it prints the full `ansible-playbook` output for both applies, so the exact task that isn't idempotent is visible directly. |
| `windows-pester` | A regression in `windows/WindowsBaseline`, or a Windows-only cmdlet behaving differently than assumed | This is the **only** job that runs on a real Windows host - it cannot be reproduced on this project's usual development machine (macOS). Read the failing test's assertion against the actual `windows-latest` runner's output in the Actions log; if a wrapper function in `windows/WindowsBaseline/Private` needs a parameter the real cmdlet doesn't expose the way the module assumes, fix the wrapper, not the test (the test only proves the orchestration logic given its inputs - the wrapper is what has to match reality). |

General rule: every job in this workflow is also just a script runnable
locally (`scripts/run-pester-tests.sh`, `scripts/run-ansible-tests.sh`, or a
handful of `terraform`/`pytest`/`ruff` commands) - CI is not a special
environment with hidden state, so reproducing a failure locally first is
almost always faster than iterating against GitHub Actions directly. The one
exception is `windows-pester`, which only runs for real on `windows-latest`.
