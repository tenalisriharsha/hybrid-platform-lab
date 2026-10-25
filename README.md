# Hybrid Platform Lab

[![CI](https://github.com/tenalisriharsha/hybrid-platform-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/tenalisriharsha/hybrid-platform-lab/actions/workflows/ci.yml)

A self-service VM platform spanning VMware vSphere, Proxmox VE and Azure. One
REST API validates every request against an approved catalog of templates and
sizes, then hands provisioning off to a backend module per platform: a
PowerCLI module for vSphere, and Terraform for Proxmox and Azure.

**Nothing in this repository touches a real vSphere, Proxmox or Azure
environment.** vSphere automation is exercised against [vcsim](https://github.com/vmware/govmomi/tree/main/vcsim),
VMware's vCenter/ESXi simulator; Terraform is exercised with `terraform plan`
and `terraform test` against mocked providers; nothing is ever applied. This
is a lab for building and testing the automation safely, not a production
provisioning system.

## Why

Teams running a mixed VMware/Proxmox/Azure estate end up with three
different ways to request a VM: a ticket, a hallway conversation, or direct
console access. Hybrid Platform Lab gives them one: a single API with an
approved catalog, owner and expiry tracking, and Prometheus metrics, backed
by infrastructure-as-code instead of manual clicks.

## Quick start

Requires Python 3.12+.

```bash
cd api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

uvicorn app.main:app --reload
```

Then open `http://127.0.0.1:8000/docs` for the interactive API, or:

```bash
curl -s -X POST http://127.0.0.1:8000/environments \
  -H 'Content-Type: application/json' \
  -d '{"name":"dev-box-1","template":"ubuntu-22.04-vsphere","size":"small","owner":"alice@example.com"}'

curl -s http://127.0.0.1:8000/environments
curl -s http://127.0.0.1:8000/metrics
```

Run the tests:

```bash
cd api
python -m pytest -v
ruff check .
```

## Preview

The interactive API docs (Swagger UI), a real create/list round trip against
the running API, the test suite passing, lint passing, and the live
Prometheus metrics endpoint:

| | |
|---|---|
| ![Swagger UI overview](docs/screenshots/01-swagger-overview.png) | ![Creating an environment](docs/screenshots/02-create-environment.png) |
| Swagger UI: every route the API exposes | `POST /environments` executed live against the running API |
| ![Listing environments](docs/screenshots/03-list-environments.png) | ![pytest suite](docs/screenshots/04-pytest-suite.png) |
| `GET /environments` returning real, seeded environments | The full pytest suite passing |
| ![ruff check](docs/screenshots/05-ruff-check.png) | ![Prometheus metrics](docs/screenshots/06-metrics-endpoint.png) |
| `ruff check .` with zero findings | `/metrics` serving live Prometheus counters and histograms |

## How it works

```
                 ┌─────────────────────────┐
  POST/GET/DELETE│   FastAPI (api/)        │   /metrics
  /environments   │   catalog validation    │──────────▶ Prometheus
────────────────▶│   owner + expiry        │
                  │   per-backend dispatch  │
                  └────────────┬────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                   ▼
     vSphere backend     Proxmox backend      Azure backend
     (PowerCLI via pwsh) (Terraform plan)     (Terraform plan)
     New-LabVM            bpg/proxmox          azurerm
```

Every request names a **template** (which fixes the backend and OS) and a
**size** (which fixes CPU/memory/disk) from a fixed catalog - `GET /catalog`
lists what's currently approved. Nothing outside that catalog is accepted.

### API

| Route | Description |
|---|---|
| `POST /environments` | Create an environment. Validates template, size, owner (email) and a `ttl_hours` (1-168h, default 24h); computes `expiry` server-side. |
| `GET /environments` | List environments, filterable by `owner`, `backend`, `status`; deleted environments are excluded unless `include_deleted=true`. |
| `GET /environments/{id}` | Fetch one environment. |
| `DELETE /environments/{id}` | Tear down an environment; marks it `deleted` rather than erasing the record, for audit. |
| `GET /catalog` | The approved templates and sizes. |
| `GET /metrics` | Prometheus text exposition: request counts/latency and a live environment gauge by backend and status. |
| `GET /healthz` | Liveness check. |

### Provisioning backends

The API never provisions anything itself - it derives a backend from the
template and delegates to it:

- **vSphere** - calls a PowerCLI module (`New-LabVM`, `Get-VMInventoryReport`,
  `Invoke-SnapshotPolicy`) through `pwsh`, tested against vcsim.
- **Proxmox** and **Azure** - render Terraform `tfvars` and run
  `terraform plan` only. Nothing is ever applied.

As of the current state of this repository, all three backends are a
`SimulatedBackend` placeholder so the API is fully testable end to end; the
real vSphere backend and the real Terraform backends are tracked in
`PROGRESS.md` and land in later phases without changing the API surface.

## Project layout

```
api/                FastAPI service: catalog, models, store, backends, routers
  app/
  tests/
docs/
  screenshots/       Preview images embedded above
PROGRESS.md          Build plan and phase-by-phase history
DAILY_REPORT.md       Written once the project is complete
```

## Status

Early stage. The FastAPI self-service API (catalog validation, the
environments CRUD surface, Prometheus metrics) is built and tested; the
PowerCLI module, Terraform modules, Ansible/PowerShell baselines and CI
pipeline are still to come. See `PROGRESS.md` for the full phase plan and
exactly what's done.

## License

[MIT](LICENSE)
