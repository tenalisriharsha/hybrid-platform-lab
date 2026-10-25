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

- [ ] **Phase 4 — Observability Stack**
  - Prometheus scrape config targeting `platform-api`; Alertmanager rules
    for health/error conditions; `promtool check` passing
  - Grafana dashboards (provisioned JSON) visualizing inventory size and
    request metrics
  - Loki + Promtail aggregating `platform-api` logs
  - `docker-compose` profile wiring the full observability stack end to end

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

**Next session starts here:** Phase 4 — Observability Stack.

Build on `observability/` (currently just a README placeholder):

- A Prometheus scrape config targeting `platform-api`'s
  `/actuator/prometheus` endpoint (already exposed since Phase 1)
- Alertmanager rules for health/error conditions (e.g. `platform-api` down,
  elevated 5xx rate)
- `promtool check config` / `promtool check rules` passing on both
- Grafana dashboards (provisioned JSON, not click-ops) visualizing
  inventory size (hosts/VMs/datastores counts, from the `/api/v1/*`
  endpoints or derived metrics) and request metrics (rate, latency, error
  rate from Micrometer)
- Loki + Promtail aggregating `platform-api`'s container logs
- A `docker-compose` profile (e.g. `docker compose --profile observability
  up`) wiring prometheus/alertmanager/grafana/loki/promtail together with
  `platform-api`, building on the images already pulled
  (`prom/prometheus`, `prom/alertmanager`, `grafana/grafana`,
  `grafana/loki`, `grafana/promtail`)
- A real (not just config-syntax) end-to-end check in the style of
  `scripts/integration-test-sync.sh`: boot the observability profile,
  confirm Prometheus is actually scraping `platform-api` (query
  `/api/v1/targets` or `/api/v1/query`), and confirm Grafana's
  provisioned dashboards/datasources loaded

Keep using Docker for all of this (already running, allowed per the
environment rules) and stay well under the ~2 GB image-size guidance.

STATUS: IN_PROGRESS
