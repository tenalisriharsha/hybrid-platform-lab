#!/usr/bin/env bash
# Installs the platform-api chart into whatever cluster the current
# kubeconfig points at, waits for it to become ready, exercises the REST
# API and actuator health endpoint through the real Service, then uninstalls
# the release. Requires the platform-api image to already be loaded into the
# cluster's container runtime (e.g. `minikube image load
# hybrid-platform-lab-platform-api:latest`).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

RELEASE="platform-api-smoke-test"

cleanup() {
  helm uninstall "$RELEASE" --wait --timeout 60s >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> helm install $RELEASE"
helm install "$RELEASE" . --wait --timeout 120s

SVC_NAME="$(kubectl get svc -l "app.kubernetes.io/instance=$RELEASE" -o jsonpath='{.items[0].metadata.name}')"

echo "==> port-forwarding the Service ($SVC_NAME)"
kubectl port-forward "svc/$SVC_NAME" 18080:8080 >/tmp/platform-api-smoke-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true; cleanup' EXIT

for _ in $(seq 1 20); do
  if curl -sf localhost:18080/actuator/health >/dev/null; then
    break
  fi
  sleep 1
done

echo "==> GET /api/v1/summary"
SUMMARY="$(curl -sf localhost:18080/api/v1/summary)"
echo "$SUMMARY"
echo "$SUMMARY" | grep -q '"hostCount"' || {
  echo "FAIL: summary response missing hostCount" >&2
  exit 1
}

echo "==> GET /actuator/health"
HEALTH="$(curl -sf localhost:18080/actuator/health)"
echo "$HEALTH"
echo "$HEALTH" | grep -q '"status":"UP"' || {
  echo "FAIL: health check did not report UP" >&2
  exit 1
}

echo "Cluster smoke test passed: platform-api is reachable and healthy via its Service."
