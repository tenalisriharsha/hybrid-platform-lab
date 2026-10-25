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

- [ ] **Phase 5 — Kubernetes & Frontend Dashboard** *(in progress — see Resume Point)*
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
  - [ ] Angular dashboard in `frontend/` — **scaffolded but not yet tested or
    verified working**: generated with `@angular/cli@18` (standalone
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
    - **Not yet done**: only one spec file exists so far
      (`app.component.spec.ts`, using `HttpTestingController` — written but
      **never run**). No tests for `platform-api.service`, `summary-panel`,
      `hosts-table`, `vms-table`, `datastores-table`, `stat-tile`, or
      `status-badge`. `npm test` / `npm run build` have not been run against
      this code at all — there may be compile errors, template errors, or
      runtime bugs not yet caught. No e2e smoke test. No Dockerfile/nginx
      config for serving the built app, and it is not wired into
      `docker-compose.yml`. No CI `frontend` job.

- [ ] **Phase 6 — Hardening & Delivery**
  - End-to-end pass across every layer with the full combined test suite green
  - Final README with complete Preview section, `DAILY_REPORT.md` written
  - `STATUS: COMPLETE` in this file

## Resume Point

**Next session starts here:** finish Phase 5 (frontend verification +
wiring), then do Phase 6.

The Helm chart and the `platform-api` summary endpoint are done, tested, and
committed (see Phase 5 above — chart tests pass, and it was actually
deployed to a real local cluster). The Angular dashboard under `frontend/`
is scaffolded and believed functionally complete (see Phase 5 above for the
full list of what was built) but **has not been run or tested yet** — treat
it as unverified. Start here, in order:

1. `cd frontend && npm install` (already run once; re-run if `node_modules`
   is missing) `&& npm run build` — fix any compile/template errors first.
2. `npm test -- --watch=false --browsers=ChromeHeadless` (or whatever
   headless launcher is available) — the existing `app.component.spec.ts`
   has never been executed. Fix failures, then write the missing specs:
   `platform-api.service.spec.ts` (HttpTestingController, one test per
   method), `summary-panel.component.spec.ts` (loading/success/error
   states for both the summary and health polls), `hosts-table`/
   `vms-table`/`datastores-table` component specs (render seeded data;
   `vms-table` additionally test the power-toggle button posts to
   `/api/v1/vms/{id}/power` and updates the row), `stat-tile` and
   `status-badge` specs (trivial render checks).
3. `ng serve` against a running `platform-api` (`docker compose up
   platform-api vcsim` or `mvn spring-boot:run`) and manually click through
   all three tabs plus a power toggle to confirm it actually works end to
   end — the proxy config (`frontend/proxy.conf.json`) should make `ng
   serve` forward `/api` and `/actuator` to `localhost:8080` without CORS
   issues, but this has not been exercised.
4. Add at least a smoke-level e2e check (Playwright, consistent with how
   screenshots are captured for this README) asserting the dashboard
   renders real data from a running `platform-api`.
5. Give the frontend a Dockerfile (build the Angular app, serve it via
   nginx, reverse-proxy `/api` and `/actuator` to `platform-api:8080` so the
   container doesn't need the dev proxy) and wire it into
   `docker-compose.yml` as its own service so `docker compose up` serves it
   end to end.
6. Add a `frontend` CI job (npm install/build/test) to
   `.github/workflows/ci.yml`.
7. Update `frontend/README.md` (still a placeholder) once the above is
   real.

Only once all of that is genuinely green should Phase 5's checkbox flip to
done. Phase 6 (hardening, full combined test suite, final README with the
Preview section refreshed to include dashboard screenshots, DAILY_REPORT.md,
`STATUS: COMPLETE`) has no slack left to build net-new features — budget
the next session's time accordingly, front-loading the frontend
verification above.

STATUS: IN_PROGRESS
