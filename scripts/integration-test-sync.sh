#!/usr/bin/env bash
# End-to-end check for the vcsim -> PowerCLI -> platform-api sync path.
#
# Boots the vcsim + platform-api containers from docker-compose.yml, runs the
# HybridPlatformSync PowerCLI module against them, and asserts the API's
# in-memory inventory reflects vcsim's simulated estate afterward. Always
# tears the containers down on exit, pass or fail.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

API_URL="http://localhost:8080"

cleanup() {
  docker compose down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Building and starting vcsim + platform-api..."
docker compose up -d --build vcsim platform-api

echo "==> Waiting for vcsim..."
for _ in $(seq 1 30); do
  if docker logs hpl-vcsim 2>&1 | grep -q "GOVC_URL"; then
    break
  fi
  sleep 1
done
docker logs hpl-vcsim 2>&1 | grep -q "GOVC_URL" || { echo "vcsim did not start"; exit 1; }

echo "==> Waiting for platform-api..."
for _ in $(seq 1 60); do
  if curl -sf "$API_URL/actuator/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -sf "$API_URL/actuator/health" >/dev/null || { echo "platform-api did not become healthy"; exit 1; }

echo "==> Seeded inventory before sync:"
curl -s "$API_URL/api/v1/hosts" | head -c 200; echo

echo "==> Running HybridPlatformSync against vcsim..."
pwsh -NoProfile -Command "
Import-Module './infra/powershell/HybridPlatformSync/HybridPlatformSync.psd1' -Force
\$cred = [pscredential]::new('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
\$result = Sync-PlatformInventory -VcsimServer '127.0.0.1' -VcsimPort 8989 -VcsimCredential \$cred -ApiBaseUrl '$API_URL'
\$result | ConvertTo-Json
if (\$result.hostCount -lt 1) { throw 'sync reported zero hosts' }
"

echo "==> Verifying platform-api reflects the synced vcsim estate..."
HOST_COUNT=$(curl -s "$API_URL/api/v1/hosts" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
VM_COUNT=$(curl -s "$API_URL/api/v1/vms" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
DS_COUNT=$(curl -s "$API_URL/api/v1/datastores" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

echo "hosts=$HOST_COUNT vms=$VM_COUNT datastores=$DS_COUNT"

if [ "$HOST_COUNT" -lt 1 ] || [ "$VM_COUNT" -lt 1 ] || [ "$DS_COUNT" -lt 1 ]; then
  echo "FAIL: expected non-empty inventory synced from vcsim"
  exit 1
fi

HOST_ID=$(curl -s "$API_URL/api/v1/hosts" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
if [[ "$HOST_ID" != HostSystem-* ]]; then
  echo "FAIL: expected a vcsim-shaped host id (HostSystem-*), got '$HOST_ID'"
  exit 1
fi

echo "PASS: platform-api inventory now reflects vcsim's live estate."
