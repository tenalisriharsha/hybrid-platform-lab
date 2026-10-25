# Observability Stack

Prometheus, Alertmanager, Grafana, Loki, and Promtail monitoring
`platform-api`, wired together via the `observability` Docker Compose
profile.

```
observability/
  prometheus/
    prometheus.yml          Scrape config (platform-api, self)
    rules/platform-api.yml  Alert rules
  alertmanager/
    alertmanager.yml        Routing (no external receiver configured)
  grafana/
    provisioning/
      datasources/          Prometheus + Loki datasources (provisioned)
      dashboards/
        dashboards.yml      Dashboard provider config
        files/
          platform-overview.json   The "Hybrid Platform Lab — Overview" dashboard
  loki/
    loki-config.yml         Single-binary Loki, filesystem storage
  promtail/
    promtail-config.yml     Docker service-discovery log scraping
```

## Running it

```bash
docker compose --profile observability up -d --build
```

This starts `vcsim` and `platform-api` (the default-profile services) plus
Prometheus, Alertmanager, Grafana, Loki, and Promtail.

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / `admin` (anonymous viewer access also enabled) |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |
| Loki | http://localhost:3100 | — (queried through Grafana) |

Tear it down with:

```bash
docker compose --profile observability down
```

## What's wired up

- **Prometheus** scrapes `platform-api:8080/actuator/prometheus` every 15s
  and loads the alert rules in `prometheus/rules/platform-api.yml`:
  `PlatformApiDown` (scrape target unreachable for 1m), `PlatformApiHighErrorRate`
  (>5% 5xx responses over 5m), and `PlatformApiNoInventory` (zero hosts in
  inventory for 5m).
- **Alertmanager** receives firing alerts from Prometheus. No external
  notification channel (Slack/email/etc.) is configured for this lab — the
  default receiver is a no-op, so alerts are visible in the Alertmanager
  UI/API without needing real credentials.
- **Grafana** auto-provisions its Prometheus and Loki datasources and the
  "Hybrid Platform Lab — Overview" dashboard on startup — nothing to
  click through manually. The dashboard shows inventory size (hosts/VMs/
  datastores, from gauges `platform_api` registers via Micrometer),
  request rate and p95 latency by endpoint, 5xx error rate, JVM heap, and
  a live `platform-api` log panel backed by Loki.
- **Loki + Promtail** aggregate container logs: Promtail discovers running
  containers via the Docker socket (`docker_sd_configs`) and ships their
  stdout/stderr to Loki, labeled by `compose_service` and `container`.

## Testing

```bash
./scripts/integration-test-observability.sh
```

Boots the full `observability` profile for real, then verifies: Prometheus
actually scraped `platform-api` (`up{job="platform-api"} == 1`), the three
alert rules loaded, the `platform_inventory_hosts` gauge is queryable,
Alertmanager responds healthy, and Grafana's provisioned datasources and
dashboard are present — via the real Prometheus/Grafana HTTP APIs, not just
config-syntax checks. Always tears the stack down on exit, pass or fail.

Config syntax is also validated directly against the pulled images:

```bash
docker run --rm -v "$PWD/prometheus:/etc/prometheus:ro" --entrypoint promtool \
  prom/prometheus check config /etc/prometheus/prometheus.yml
docker run --rm -v "$PWD/prometheus:/etc/prometheus:ro" --entrypoint promtool \
  prom/prometheus check rules /etc/prometheus/rules/platform-api.yml
docker run --rm -v "$PWD/alertmanager:/etc/alertmanager:ro" --entrypoint amtool \
  prom/alertmanager check-config /etc/alertmanager/alertmanager.yml
```

(run from `observability/`)
