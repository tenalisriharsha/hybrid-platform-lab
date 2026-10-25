# Hybrid Platform Lab

[![CI](https://github.com/tenalisriharsha/hybrid-platform-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/tenalisriharsha/hybrid-platform-lab/actions/workflows/ci.yml)

A small, integrated hybrid-infrastructure control plane: a simulated
VMware estate, a Java control-plane API, infrastructure-as-code, and a
full observability stack, wired together the way a real platform team's
tooling is — not as separate, disconnected demos.

**Hybrid Platform Lab** models that intersection end to end:

- A simulated VMware estate (hosts, VMs, datastores) running on `vcsim`
- **`platform-api`** — a Java/Spring Boot control-plane service owning the
  inventory domain model, exposed over REST and Prometheus metrics
- PowerShell/PowerCLI automation syncing live inventory from `vcsim`
- Terraform + Ansible describing and configuring platform resources as code
- Prometheus, Alertmanager, Grafana, Loki, and Promtail observing the
  platform
- An Angular dashboard visualizing inventory and platform health
- A Helm chart deploying `platform-api` to Kubernetes

## Preview

**Backend test suite** — unit and integration tests covering the inventory
domain, service, and REST/Actuator endpoints.

![Backend test suite](docs/screenshots/01-backend-tests.png)

**Inventory API** — hosts, VMs, and datastores from the simulated estate.

![Inventory API](docs/screenshots/02-inventory-api.png)

**VM power state and error handling** — changing a VM's power state and a
`ProblemDetail` 404 response for an unknown resource.

![Power state and error handling](docs/screenshots/03-power-state-and-errors.png)

**Prometheus metrics** — per-endpoint request metrics exposed at
`/actuator/prometheus`, ready for the observability stack in Phase 4.

![Prometheus metrics](docs/screenshots/04-prometheus-metrics.png)

**Containerized stack** — `platform-api` running alongside the simulated
`vcsim` vCenter via `docker compose`.

![Docker compose stack](docs/screenshots/05-docker-compose-stack.png)

**Project layout** — the full scaffold for every track of the platform.

![Project layout](docs/screenshots/06-project-layout.png)

## Quick Start

Requires Java 21, Maven, and Docker.

```bash
# Run the test suite
cd backend && mvn test

# Run platform-api + the simulated vCenter (vcsim) together
docker compose up -d --build

curl http://localhost:8080/api/v1/hosts
curl http://localhost:8080/actuator/health
```

`platform-api` listens on `http://localhost:8080`:

| Endpoint | Description |
|---|---|
| `GET /api/v1/hosts` | List ESXi hosts in the simulated estate |
| `GET /api/v1/vms` | List virtual machines |
| `POST /api/v1/vms/{id}/power` | Change a VM's power state |
| `GET /api/v1/datastores` | List datastores |
| `POST /api/v1/sync` | Replace the in-memory inventory with a synced estate |
| `GET /api/v1/info` | Platform metadata |
| `GET /actuator/health` | Liveness/readiness |
| `GET /actuator/prometheus` | Prometheus-formatted metrics |

### Syncing live inventory from vcsim

The `HybridPlatformSync` PowerCLI module in `infra/powershell/` connects to
`vcsim`, pulls its hosts/VMs/datastores, and posts them to `platform-api` so
the API reflects a real (simulated) vSphere estate instead of its seeded
sample data:

```bash
# with vcsim + platform-api already running (e.g. via docker compose up -d)
pwsh -NoProfile -Command '
  Import-Module ./infra/powershell/HybridPlatformSync/HybridPlatformSync.psd1
  $cred = [pscredential]::new("user", (ConvertTo-SecureString "pass" -AsPlainText -Force))
  Sync-PlatformInventory -VcsimServer 127.0.0.1 -VcsimPort 8989 -VcsimCredential $cred -ApiBaseUrl "http://localhost:8080"
'
```

Or run the full end-to-end check (boots both containers, syncs, verifies, tears down):

```bash
./scripts/integration-test-sync.sh
```

## Architecture

```
                         ┌─────────────────────┐
                         │   Angular Dashboard  │
                         │   (frontend/)        │
                         └──────────┬───────────┘
                                    │ REST
                         ┌──────────▼───────────┐
                         │     platform-api      │
                         │   (backend/, Java)    │
                         │  Inventory domain:    │
                         │  Host / VM / Datastore │
                         │  REST + Actuator +    │
                         │  Micrometer metrics   │
                         └──────┬───────┬────────┘
                                │       │
     POST /api/v1/sync inventory│       │ /actuator/prometheus
                                │       │
          ┌─────────────────┐  │       │  ┌────────────────────────┐
          │ PowerShell /     │  │       │  │ Prometheus              │
          │ PowerCLI module  │  │       │  │  → Alertmanager         │
          │ (infra/powershell)│ │       │  │  → Grafana dashboards   │
          │ talks to vcsim   │◄─┘       └──│  → Loki + Promtail logs │
          └────────┬─────────┘             │ (observability/)        │
                   │ SOAP/API               └──────────────────────┘
          ┌────────▼─────────┐
          │  vcsim container  │
          │ (simulated vCenter)│
          └───────────────────┘
```

Repo layout:

```
backend/            Java 21 / Spring Boot control-plane API (platform-api)
frontend/           Angular dashboard (visualizes inventory + health)
infra/terraform/    Terraform modules describing platform resources
infra/ansible/      Ansible playbooks/roles for platform configuration
infra/powershell/   PowerCLI module syncing inventory from vcsim
observability/      Prometheus, Alertmanager, Grafana, Loki, Promtail configs
helm/               Helm chart for deploying platform-api to Kubernetes
docs/screenshots/   Preview images
```

## Testing

```bash
cd backend && mvn test
```

35 unit and integration tests cover the inventory domain model, the
in-memory inventory service (including inventory sync), and every
REST/Actuator endpoint.

```bash
pwsh -NoProfile -File infra/powershell/Run-Tests.ps1
```

Runs PSScriptAnalyzer and the Pester suite for the `HybridPlatformSync`
module (datastore/host/VM conversion, JSON export, and the sync flow).

## Status

`platform-api` (inventory domain, REST API, Actuator/Prometheus metrics,
containerized with `vcsim`) and the `HybridPlatformSync` PowerCLI module
(pulling live inventory out of `vcsim` and syncing it into `platform-api`)
are implemented and tested. Infrastructure-as-code, the observability
stack, Kubernetes deployment, and the Angular dashboard are in progress.
See [PROGRESS.md](PROGRESS.md) for the full phase-by-phase build plan and
history.

## License

MIT — see [LICENSE](LICENSE).
