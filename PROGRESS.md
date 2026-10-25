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

- [ ] **Phase 3 — Infrastructure as Code**
  - Terraform modules in `infra/terraform/` describing platform resources
    (vsphere-provider resources against `vcsim` where possible, mocked
    elsewhere); validated with `terraform fmt`/`validate` and
    `terraform test` using `mock_provider` (no real cloud calls)
  - Ansible playbooks/roles in `infra/ansible/` for platform configuration
    tasks, clean `ansible-lint`, and check-mode based assertions as tests

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

**Next session starts here:** Phase 3 — Infrastructure as Code.

Start with Terraform modules under `infra/terraform/` describing platform
resources — model them against the `vsphere` provider pointed at `vcsim`
where that's realistic (hosts/VMs/datastores already have real analogues
there), and mock elsewhere. Validate with `terraform fmt -check`,
`terraform validate`, and `terraform test` using `mock_provider` (no real
cloud/vCenter calls — `vcsim` plan-level usage, if attempted, should stay
read-only and bounded). Then write Ansible playbooks/roles under
`infra/ansible/` for platform configuration tasks (e.g. shaping
`platform-api`'s `application.yml`, or an `infra/powershell`-adjacent
config step), keep `ansible-lint` clean, and use check-mode runs as the
test layer (no real hosts to configure against, so assert on the
diff/changed-resources output of `--check --diff`). Do not run
`terraform apply`/`destroy` or any real AWS/cloud credentials — only dummy
credentials exist in this environment.

STATUS: IN_PROGRESS
