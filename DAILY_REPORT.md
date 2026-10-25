# Daily Report

A summary of what was built across the project, final test results, known
limitations, and ideas for future work. See [PROGRESS.md](PROGRESS.md) for
the detailed phase-by-phase build log.

## What was built

**`platform-api`** (Java 21 / Spring Boot) — the control-plane service
owning the inventory domain model (Host / VirtualMachine / Datastore), with:

- REST endpoints for listing and mutating inventory (`/api/v1/hosts`,
  `/api/v1/vms`, `/api/v1/datastores`, VM power control), a dashboard
  summary rollup (`/api/v1/summary`), and an atomic sync endpoint
  (`/api/v1/sync`) that validates referential integrity (every VM must
  reference a host in the same payload) before replacing the in-memory
  estate
- Actuator health groups (liveness/readiness) and Micrometer metrics,
  including custom inventory-size gauges and percentile-histogram request
  latency buckets, exposed at `/actuator/prometheus`
- A Dockerfile and a `docker-compose.yml` wiring it with `vcsim`

**`HybridPlatformSync`** (PowerShell/PowerCLI) — connects to `vcsim`,
enumerates the simulated vSphere estate, converts it to `platform-api`'s
JSON shape, and posts it to `/api/v1/sync`, so the platform reflects a real
(simulated) estate instead of static seed data.

**Infrastructure as code** — a Terraform module (`vmware/vsphere` provider)
describing the lab's datacenter/cluster/hosts/datastores, validated against
a mocked provider with no real credentials or network calls; an Ansible
role rendering environment-specific configuration for `platform-api` and
`HybridPlatformSync` from one set of variables, with input validation.

**Observability** — a full Prometheus / Alertmanager / Grafana / Loki /
Promtail stack: scrape config and alert rules for `platform-api`,
auto-provisioned Grafana datasources and an overview dashboard (inventory
size, request rate/p95 latency, error rate, JVM heap, live logs), and
Promtail shipping container logs via Docker service discovery — all
reachable through a single `docker compose --profile observability up`.

**Kubernetes** — a Helm chart deploying `platform-api` with 2 replicas, a
`ClusterIP` Service, and startup/liveness/readiness probes wired to Spring
Boot's health probe groups. Actually deployed and verified against a real
local Kubernetes cluster (minikube, docker driver).

**Dashboard** (Angular) — a standalone Angular app visualizing live
inventory and platform health: a summary panel (health badge + stat tiles,
polling every 15 seconds) and three tabs (hosts, VMs with a power toggle,
datastores with capacity usage bars). Served in production via nginx,
reverse-proxying `/api` and `/actuator` to `platform-api`, wired into
`docker-compose.yml` as its own service.

## Test results

All of the following were re-run and confirmed passing:

| Layer | Command | Result |
|---|---|---|
| Backend | `cd backend && mvn test` | 41 tests, 0 failures |
| Frontend (unit) | `cd frontend && npm test -- --watch=false --browsers=ChromeHeadless` | 29 specs, 0 failures |
| Frontend (e2e) | `cd frontend && npm run e2e` (against a real `platform-api` + `ng serve`) | 3 tests, 0 failures |
| Terraform | `cd infra/terraform/modules/vsphere-estate && terraform test` | 6 cases, 0 failures |
| Ansible | `cd infra/ansible && ./tests/run-tests.sh` | lint clean, all role assertions pass |
| Helm | `helm/platform-api/tests/run-tests.sh` | lint clean, all rendering assertions pass |
| Observability | `promtool check config/rules`, `amtool check-config` | all clean |

The frontend's `docker-compose.yml`-wired Dockerfile was built and smoke
tested standalone (static page and `/api` reverse proxy both returned
`200`, final image 76 MB). `docker compose config` validates the full
compose file including the new `frontend` service.

CI (`.github/workflows/ci.yml`) runs all of the above except the e2e
Playwright suite and the Helm cluster smoke test, both of which need a
real running stack / cluster rather than a hermetic CI job.

## Known limitations

- The VMware integration targets `vcsim` (a vCenter simulator), not a real
  vCenter — `HybridPlatformSync` has not been exercised against real
  vSphere infrastructure.
- Terraform is validated against a mocked provider only; it has never been
  applied against a real cloud or on-prem vSphere environment.
- `platform-api`'s inventory is in-memory — it resets on restart unless
  re-synced from `vcsim`. There is no persistent datastore.
- The dashboard has no authentication; it assumes a trusted internal
  network, consistent with `platform-api`'s permissive CORS config for this
  lab setting.
- The Playwright e2e suite and the Helm cluster smoke test are not run in
  CI since they require a live backend/cluster rather than a hermetic job.

## Future ideas

- Persist inventory (e.g. Postgres) so `platform-api` survives restarts
  without a re-sync.
- Add authentication/authorization to `platform-api` and the dashboard.
- Extend `HybridPlatformSync` with a scheduled sync mode (e.g. a systemd
  timer or Kubernetes CronJob) instead of one-shot manual runs.
- Add Grafana alerting routes (Slack/email) to Alertmanager beyond the
  current no-op receiver.
- Add dashboard views for Terraform/Ansible state and the Helm release, so
  the dashboard reflects the IaC layer, not just live inventory.
