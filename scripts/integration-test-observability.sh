#!/usr/bin/env bash
# End-to-end check for the observability stack: Prometheus, Alertmanager,
# Grafana, Loki, and Promtail wired up against platform-api.
#
# Boots the full observability profile via docker-compose, confirms
# Prometheus is actually scraping platform-api, confirms Alertmanager is
# reachable, and confirms Grafana's provisioned datasources and dashboard
# loaded. Always tears the containers down on exit, pass or fail.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROM_URL="http://localhost:9090"
AM_URL="http://localhost:9093"
GRAFANA_URL="http://localhost:3000"

cleanup() {
  docker compose --profile observability down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Building and starting the observability profile..."
docker compose --profile observability up -d --build

echo "==> Waiting for platform-api..."
for _ in $(seq 1 60); do
  curl -sf "http://localhost:8080/actuator/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -sf "http://localhost:8080/actuator/health" >/dev/null || { echo "platform-api did not become healthy"; exit 1; }

echo "==> Waiting for Prometheus..."
for _ in $(seq 1 60); do
  curl -sf "$PROM_URL/-/ready" >/dev/null 2>&1 && break
  sleep 1
done
curl -sf "$PROM_URL/-/ready" >/dev/null || { echo "Prometheus did not become ready"; exit 1; }

echo "==> Waiting for Prometheus to scrape platform-api at least once..."
PLATFORM_API_UP=""
for _ in $(seq 1 60); do
  HEALTH=$(curl -s "$PROM_URL/api/v1/query" --data-urlencode 'query=up{job="platform-api"}')
  VALUE=$(echo "$HEALTH" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
print(results[0]['value'][1] if results else '')
")
  if [ "$VALUE" = "1" ]; then
    PLATFORM_API_UP="1"
    break
  fi
  sleep 2
done
if [ "$PLATFORM_API_UP" != "1" ]; then
  echo "FAIL: Prometheus never reported up{job=\"platform-api\"} == 1"
  exit 1
fi
echo "    platform-api target is up in Prometheus."

echo "==> Verifying the platform-api alert rules loaded..."
RULE_COUNT=$(curl -s "$PROM_URL/api/v1/rules" | python3 -c "
import json, sys
data = json.load(sys.stdin)
groups = data.get('data', {}).get('groups', [])
print(sum(len(g['rules']) for g in groups))
")
if [ "$RULE_COUNT" -lt 1 ]; then
  echo "FAIL: expected platform-api alert rules to be loaded, found $RULE_COUNT"
  exit 1
fi
echo "    $RULE_COUNT alert rule(s) loaded."

echo "==> Verifying inventory-size metrics are visible in Prometheus..."
INVENTORY_HOSTS=$(curl -s "$PROM_URL/api/v1/query" --data-urlencode 'query=platform_inventory_hosts' | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
print(results[0]['value'][1] if results else '')
")
if [ -z "$INVENTORY_HOSTS" ]; then
  echo "FAIL: platform_inventory_hosts metric not visible in Prometheus"
  exit 1
fi
echo "    platform_inventory_hosts=$INVENTORY_HOSTS"

echo "==> Checking Alertmanager is reachable..."
curl -sf "$AM_URL/-/healthy" >/dev/null || { echo "FAIL: Alertmanager not healthy"; exit 1; }

echo "==> Waiting for Grafana..."
for _ in $(seq 1 60); do
  curl -sf "$GRAFANA_URL/api/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -sf "$GRAFANA_URL/api/health" >/dev/null || { echo "FAIL: Grafana did not become healthy"; exit 1; }

echo "==> Verifying Grafana's provisioned datasources loaded..."
DS_COUNT=$(curl -s -u admin:admin "$GRAFANA_URL/api/datasources" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
if [ "$DS_COUNT" -lt 2 ]; then
  echo "FAIL: expected 2 provisioned Grafana datasources, found $DS_COUNT"
  exit 1
fi
echo "    $DS_COUNT datasource(s) provisioned."

echo "==> Verifying Grafana's provisioned dashboard loaded..."
DASHBOARD_FOUND=$(curl -s -u admin:admin "$GRAFANA_URL/api/search?query=Overview" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('1' if any(d.get('uid') == 'hpl-overview' for d in data) else '0')
")
if [ "$DASHBOARD_FOUND" != "1" ]; then
  echo "FAIL: expected provisioned dashboard 'hpl-overview' not found"
  exit 1
fi
echo "    Dashboard 'hpl-overview' provisioned."

echo "PASS: observability stack is wired up end to end."
