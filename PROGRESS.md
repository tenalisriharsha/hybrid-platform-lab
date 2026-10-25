# Hybrid Platform Lab — Build Progress

## Vision

Most infrastructure portfolios pick one lane: a Terraform repo, a Kubernetes
manifest set, or a monitoring dashboard. Real platform teams live at the
intersection of virtualization, infrastructure-as-code, container
orchestration, and observability — often all pointed at the same estate.

**Hybrid Platform Lab** is a single, integrated control plane that models
that intersection:

- A simulated VMware estate (hosts, VMs, datastores) running on `vcsim`
- A Java control-plane API (`platform-api`) that owns the inventory domain
  model and exposes it over REST and Prometheus metrics
- PowerShell/PowerCLI automation that syncs live inventory from vcsim into
  the platform
- Terraform + Ansible describing and configuring platform resources as code
- A Prometheus / Alertmanager / Grafana / Loki / Promtail stack observing
  the platform end to end
- An Angular dashboard visualizing inventory and platform health
- A Helm chart deploying `platform-api` to Kubernetes

The goal is a lab that behaves like a small, real hybrid platform team's
tooling — not a toy demo of any single technology.

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
            sync inventory JSON │       │ /actuator/prometheus
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

   Terraform (infra/terraform) + Ansible (infra/ansible) describe and
   configure the platform's own resources as code.
   Helm chart (helm/) deploys platform-api to Kubernetes.
```

Repo layout:

```
backend/            Java 21 / Spring Boot control-plane API ("platform-api")
frontend/           Angular dashboard (visualizes inventory + health)
infra/terraform/    Terraform modules describing platform resources
infra/ansible/      Ansible playbooks/roles for platform configuration
infra/powershell/   PowerCLI module syncing inventory from vcsim
observability/      Prometheus, Alertmanager, Grafana, Loki, Promtail configs
helm/               Helm chart for deploying platform-api to Kubernetes
docs/screenshots/   Captured preview images for the README
scripts/            Automation scripts (e.g. screenshot capture)
```

## Sprint Plan — 6 Sessions

This project is built across exactly 6 long working sessions. Each phase is
sized to fit one session.

- [x] **Phase 1 — Foundation & Core Platform API** *(this session)*
  - Full repo scaffold for every track (backend, frontend, infra, observability, helm)
  - `platform-api` Java/Spring Boot service: Host / VirtualMachine / Datastore
    domain model, in-memory inventory service, REST endpoints, Actuator +
    Micrometer Prometheus metrics endpoint
  - Unit tests (domain + service) and integration tests (REST layer via
    Spring Boot Test / MockMvc)
  - Dockerfile for `platform-api` + `docker-compose.yml` wiring it with
    `vcsim`
  - GitHub Actions CI workflow (Maven build + test)
  - MIT license, README with quick start, CI badge, and Preview section

- [x] **Phase 2 — VMware Integration Layer**
  - `HybridPlatformSync` PowerCLI module in `infra/powershell/`: connects to
    `vcsim`, enumerates hosts/VMs/datastores, converts them to
    `platform-api`'s JSON shape, and can export or POST that snapshot
  - 9 Pester tests (conversion functions + the connect/snapshot/post/
    disconnect flow, mocked — no live vcsim needed) and a clean
    PSScriptAnalyzer pass (`infra/powershell/Run-Tests.ps1`)
  - `platform-api` gained `POST /api/v1/sync`: atomically replaces the
    in-memory hosts/VMs/datastores with a synced estate, validating that
    every synced VM references a host in the same payload before
    committing (rejects with 400 otherwise, leaving prior state intact).
    The Phase 1 seed data is now purely a fallback shown until the first
    sync lands
  - `scripts/integration-test-sync.sh`: a real end-to-end check that boots
    `vcsim` + `platform-api` via `docker compose`, runs
    `Sync-PlatformInventory` against them, and asserts the API's inventory
    reflects vcsim's live (simulated) estate — verified passing locally

- [x] **Phase 3 — Infrastructure as Code**
  - `infra/terraform/modules/vsphere-estate`: a Terraform module against
    the `vmware/vsphere` provider describing the lab's vSphere estate —
    datacenter, compute cluster, ESXi hosts, NAS datastores. Capacity
    numbers (CPU/memory) and VMs are deliberately left out: those are
    properties of real hardware/workloads, observed live through
    `HybridPlatformSync`, not declared as code. Host passwords are passed
    via a separate `host_passwords` map so `hosts` can stay a
    non-sensitive `for_each` key
  - `infra/terraform/environments/lab`: a root module wiring the module
    for this lab's topology, plus a `terraform.tfvars.example` with
    placeholder-only credentials
  - 6 `terraform test` cases against a `mock_provider` (no network call,
    no real credentials) covering the expected plan topology and every
    variable validation rule (empty/duplicate hosts, duplicate
    datastores, a host missing its password); `terraform fmt -check` and
    `terraform validate` both clean on the module and the lab environment
  - `infra/ansible/roles/platform_config`: renders a `platform-api` Spring
    Boot config overlay and a `HybridPlatformSync` connection-settings
    JSON from one set of variables, with an `assert` task rejecting
    out-of-range input before anything is written
  - `infra/ansible/tests/run-tests.sh`: `ansible-lint` (clean at the
    `production` profile) plus a real exercise of the role — check-mode
    dry run, a real run, an idempotency check, variable overrides, and a
    rejected invalid input — all against `localhost`, no real hosts
  - CI (`.github/workflows/ci.yml`) gained `terraform` and `ansible` jobs
    alongside the existing `backend` job

- [x] **Phase 4 — Observability Stack**
  - `platform-api` gained three Micrometer gauges (`platform_inventory_hosts`,
    `platform_inventory_vms`, `platform_inventory_datastores`) tracking the
    live inventory size, plus percentile-histogram buckets enabled for
    `http.server.requests` so p95 latency can be queried via
    `histogram_quantile`. 2 new unit tests cover the gauges (37 backend
    tests total)
  - `observability/prometheus/`: scrape config targeting
    `platform-api:8080/actuator/prometheus`, and 3 alert rules
    (`PlatformApiDown`, `PlatformApiHighErrorRate`, `PlatformApiNoInventory`)
    — `promtool check config`/`check rules` both clean (run via the pulled
    `prom/prometheus` image, no local promtool binary needed)
  - `observability/alertmanager/`: routing config with a no-op default
    receiver (no real notification channel needed for a lab) —
    `amtool check-config` clean
  - `observability/grafana/`: auto-provisioned Prometheus + Loki
    datasources and a "Hybrid Platform Lab — Overview" dashboard (inventory
    size, request rate/p95 latency by endpoint, 5xx error rate, JVM heap,
    live log panel) — nothing requires manual click-ops setup
  - `observability/loki/` + `observability/promtail/`: single-binary Loki
    with filesystem storage; Promtail discovers containers via Docker
    service discovery (`docker_sd_configs` against the Docker socket) and
    ships their logs to Loki, labeled by `compose_service`/`container`
  - `docker-compose.yml` gained an `observability` Compose profile
    (`docker compose --profile observability up`) wiring all five services
    alongside `vcsim`/`platform-api`
  - `scripts/integration-test-observability.sh`: boots the real profile,
    confirms via the Prometheus HTTP API that `platform-api` is actually
    being scraped (`up{job="platform-api"} == 1`) and the alert rules
    loaded, confirms `platform_inventory_hosts` is queryable, confirms
    Alertmanager is healthy, and confirms Grafana's datasources/dashboard
    provisioned — verified passing locally, including a manual check that
    Promtail-shipped `platform-api` logs are actually queryable in Loki
  - CI (`.github/workflows/ci.yml`) gained an `observability` job running
    the `promtool`/`amtool` config checks

- [ ] **Phase 5 — Kubernetes & Frontend Dashboard**
  - Helm chart in `helm/` for `platform-api` (passing `helm lint` /
    `helm template`) plus equivalent kubectl manifests
  - Angular dashboard in `frontend/` consuming the API: inventory table,
    health/status view, metrics summary
  - Component/e2e smoke tests for the dashboard

- [ ] **Phase 6 — Hardening & Delivery**
  - End-to-end pass across every layer with the full combined test suite green
  - Final README with complete Preview section, `DAILY_REPORT.md` written
  - `STATUS: COMPLETE` in this file

## Resume Point

**Next session starts here:** Phase 5 — Kubernetes & Frontend Dashboard.

Build on `helm/` and `frontend/` (currently README placeholders):

- A Helm chart in `helm/` for `platform-api`: Deployment, Service, and a
  values file exposing image/replica/resource/env configuration. Must pass
  `helm lint` and `helm template` cleanly; consider a `helm unittest` or
  `helm template` + assertion-based test for key rendered fields (image
  tag, port, env vars). Equivalent plain kubectl manifests alongside it
  (or generated via `helm template > manifests/`) so the chart's output is
  inspectable without a cluster.
- Validate the chart actually deploys: `kubectl` + `kind`/`minikube` is
  available in this environment, or at minimum exercise it with `helm
  template` output applied to a local cluster if one is cheap to spin up
  (check what's available before assuming — Docker Desktop's Kubernetes or
  `minikube` via the `gcr.io/k8s-minikube/kicbase` image already pulled
  may already be usable)
- An Angular dashboard in `frontend/` consuming `platform-api`: an
  inventory table (hosts/VMs/datastores, pulling from `GET /api/v1/hosts`
  etc.), a health/status view (`GET /actuator/health`), and a metrics
  summary (could reuse the inventory-size gauges or call `/actuator/
  prometheus` and parse, or better, have `platform-api` expose a small
  summary REST endpoint purpose-built for the dashboard rather than
  parsing Prometheus text format client-side — worth deciding early)
- Component tests for the Angular dashboard (e.g. Jasmine/Karma or the
  modern Angular testing setup) and at least a smoke-level e2e check
  (could be Playwright, consistent with how screenshots are captured for
  this README) asserting the dashboard renders real data from a running
  `platform-api`
- Wire the dashboard into `docker-compose.yml` (its own service/profile,
  or folded into the existing default services) so `docker compose up`
  can serve it end to end alongside `platform-api`
- Update CI (`.github/workflows/ci.yml`) with a `frontend` job (npm
  install/build/test) and, if feasible without excessive CI time, a
  `helm lint`/`helm template` job

This is the last unimplemented functional phase — Phase 6 is hardening,
final README/DAILY_REPORT, and the preview screenshot refresh. Budget
Phase 5 time accordingly: get the Helm chart and dashboard both genuinely
working and tested, since Phase 6 has no slack to build net-new features.

STATUS: IN_PROGRESS
