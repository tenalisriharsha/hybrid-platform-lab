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

- [x] **Phase 5 — Kubernetes & Frontend Dashboard**
  - [x] Helm chart in `helm/platform-api/` for `platform-api`: Deployment (2
    replicas), ClusterIP Service, dedicated ServiceAccount, startup/liveness/
    readiness probes wired to Spring Boot Actuator's health probe groups
    (`management.endpoint.health.probes.enabled: true`, added to
    `application.yml`). `helm lint --strict` clean; `helm/platform-api/
    tests/run-tests.sh` asserts rendered output (default values + overridden
    replicaCount/image.tag/env + serviceAccount.create=false) with no cluster
    needed; static `helm template` output committed at `helm/platform-api/
    manifests/platform-api.yaml`. **Actually deployed and verified against a
    real local Kubernetes cluster** (existing `minikube` profile, docker
    driver): built the backend image, `minikube image load`ed it, `helm
    install`ed the chart, confirmed both replicas reach `Running`/`Ready`,
    and curled `/api/v1/summary` + `/actuator/health` through the real
    Service — see `helm/platform-api/tests/cluster-smoke-test.sh`, which
    automates that whole install/verify/uninstall flow against whatever
    cluster the current kubeconfig points at. CI gained a `helm` job running
    the no-cluster chart tests
  - [x] `platform-api` gained `GET /api/v1/summary`: a dashboard-friendly
    rollup (host/VM/datastore counts, VM power-state breakdown, aggregate
    datastore capacity/free) computed on demand from the live inventory maps,
    so the dashboard doesn't need to fetch every entity or parse the
    Prometheus text format client-side. Plus a permissive CORS config
    (`WebConfig`) so the Angular dev server / dashboard container can call
    the API cross-origin. 5 new backend tests (service + controller); 46
    backend tests total, all passing
  - [x] Angular dashboard in `frontend/` — built out, verified, and tested
    end to end: generated with `@angular/cli@18` (standalone
    components, no routing module, zoneless-ready). Built out:
    - `core/platform-api.service.ts` + `core/models/inventory.ts`: typed
      HTTP client for `/api/v1/{summary,hosts,vms,datastores}` +
      `POST /api/v1/vms/{id}/power` + `/actuator/health`
    - `shared/status-badge/`: reusable status badge (good/warning/serious/
      critical/muted) using the dataviz skill's fixed status palette
    - `dashboard/stat-tile/`, `dashboard/summary-panel/`: stat-tile row for
      the inventory summary + a health badge, auto-refreshing every 15s via
      RxJS (`timer` + `switchMap`, cleaned up with `takeUntilDestroyed`)
    - `dashboard/hosts-table/`, `dashboard/vms-table/` (with a power-on/off
      toggle button calling the power endpoint), `dashboard/datastores-table/`
      (with a capacity usage bar using the dataviz sequential blue hue)
    - `app.component`: header + summary panel + a 3-tab inventory section
      (Hosts/VMs/Datastores)
    - `proxy.conf.json` wired into `angular.json`'s `serve` target so
      `ng serve` proxies `/api` and `/actuator` to `localhost:8080`
    - Global theme tokens (light/dark, `prefers-color-scheme` + `data-theme`
      override) added to `src/styles.css` from the dataviz skill's reference
      palette
    - `npm run build` succeeds; `npm test -- --watch=false --browsers=
      ChromeHeadless` runs 29 specs, all passing: `app.component.spec.ts`
      (fixed — it assumed `timer(0, ...)` emits synchronously on
      `detectChanges()`, which it doesn't; rewritten with `fakeAsync`/
      `tick()`/`discardPeriodicTasks()`), plus new specs for
      `platform-api.service` (one test per HTTP method via
      `HttpTestingController`), `summary-panel` (loading/success/error
      states for both the summary and health polls, including a second
      15s poll tick), `hosts-table`/`vms-table`/`datastores-table`
      (rendered rows, empty state, error state; `vms-table` additionally
      covers the suspended-VM disabled button and the power toggle
      actually posting and updating the row), and `stat-tile`/
      `status-badge` (render checks)
    - `ng serve --proxy-config proxy.conf.json` run against a real
      `mvn spring-boot:run` `platform-api`, exercised with a headless
      Playwright script: all three tabs render live seeded data, the VM
      power toggle posts to `/api/v1/vms/{id}/power` and updates the row,
      and dark mode (`prefers-color-scheme`) renders correctly — confirmed
      by inspecting the captured screenshots
    - `frontend/e2e/smoke.spec.ts`: a Playwright suite (3 tests) against
      the same real `ng serve` + `platform-api` pair — dashboard loads
      real inventory/health, tab switching loads VMs/datastores, and the
      power toggle call updates the row. `npm run e2e` runs it
    - `frontend/Dockerfile` (multi-stage: `npm run build` under
      `node:20-alpine`, served by `nginx:1.27-alpine`) + `nginx.conf`
      reverse-proxying `/api` and `/actuator` to `platform-api:8080` —
      built and smoke-tested standalone (static page + API proxy both
      returned 200, image is 76 MB). Wired into `docker-compose.yml` as a
      `frontend` service on port 4200, depending on `platform-api`
    - CI (`.github/workflows/ci.yml`) gained a `frontend` job (npm ci,
      build, `ng test --browsers=ChromeHeadless`)
    - `frontend/README.md` rewritten with real dev/test/Docker instructions

- [x] **Phase 6 — Hardening & Delivery**
  - Full combined test suite re-run clean in this session: backend 41
    tests, frontend 29 unit specs + 3 Playwright e2e tests, Terraform 6
    `terraform test` cases (+ `fmt`/`validate`), the full Ansible
    `run-tests.sh` (lint + check-mode + real run + idempotency +
    overrides + rejected input), the Helm chart's `run-tests.sh` (lint +
    4 rendering assertions), and the observability `promtool`/`amtool`
    config checks — nothing left failing or unverified
  - 4 new dashboard screenshots captured with Playwright against the real
    running stack (hosts tab, VMs tab with a mixed power state and the
    toggle button, datastores tab with usage bars, dark mode), each opened
    and visually checked before being embedded; README Preview section now
    has 14 images total covering every layer of the platform
  - README finalized: Quick Start covers the dashboard, a Dashboard and a
    Kubernetes subsection added under the running-the-stack instructions,
    the endpoint table gained `/api/v1/summary`, Testing covers the
    frontend/Helm suites, Status reflects every layer as done
  - `DAILY_REPORT.md` written
  - `STATUS: COMPLETE` in this file

## Resume Point

This project is complete. All six phases are implemented, tested, and
documented — see the phase list above for what was built and how it was
verified, and `DAILY_REPORT.md` for the full build summary, test results,
known limitations, and future ideas. There is no planned next step; if
resuming work on this repo, start by re-running the combined test suite
listed in README's Testing section to confirm nothing has drifted, then
treat anything in DAILY_REPORT.md's "Future ideas" section as the backlog.

STATUS: COMPLETE
