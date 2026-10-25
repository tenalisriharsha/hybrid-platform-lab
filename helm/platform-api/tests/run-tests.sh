#!/usr/bin/env bash
# Lints the platform-api Helm chart and asserts key fields of its rendered
# output, without needing a live cluster.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

echo "==> helm lint"
helm lint . --strict

RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT

echo "==> helm template (default values)"
helm template platform-api . >"$RENDERED"

grep -q 'kind: Deployment' "$RENDERED" || fail "no Deployment rendered"
grep -q 'kind: Service' "$RENDERED" || fail "no Service rendered"
grep -q 'kind: ServiceAccount' "$RENDERED" || fail "no ServiceAccount rendered"
grep -q 'replicas: 2' "$RENDERED" || fail "default replicaCount not rendered"
grep -q 'image: "hybrid-platform-lab-platform-api:latest"' "$RENDERED" || fail "default image not rendered"
grep -q 'containerPort: 8080' "$RENDERED" || fail "container port not rendered"
grep -q 'path: /actuator/health/liveness' "$RENDERED" || fail "liveness probe path not rendered"
grep -q 'path: /actuator/health/readiness' "$RENDERED" || fail "readiness probe path not rendered"

echo "==> helm template (overridden values: replicaCount, image.tag, env)"
OVERRIDDEN="$(mktemp)"
trap 'rm -f "$RENDERED" "$OVERRIDDEN"' EXIT
helm template platform-api . \
  --set replicaCount=4 \
  --set image.tag=1.2.3 \
  --set-json 'env=[{"name":"SPRING_PROFILES_ACTIVE","value":"lab"}]' \
  >"$OVERRIDDEN"

grep -q 'replicas: 4' "$OVERRIDDEN" || fail "overridden replicaCount not rendered"
grep -q 'image: "hybrid-platform-lab-platform-api:1.2.3"' "$OVERRIDDEN" || fail "overridden image tag not rendered"
grep -q 'value: lab' "$OVERRIDDEN" || fail "overridden env var not rendered"

echo "==> helm template (serviceAccount.create=false falls back to default SA)"
NOSA="$(mktemp)"
trap 'rm -f "$RENDERED" "$OVERRIDDEN" "$NOSA"' EXIT
helm template platform-api . --set serviceAccount.create=false >"$NOSA"
grep -q 'kind: ServiceAccount' "$NOSA" && fail "ServiceAccount should not render when serviceAccount.create=false"
grep -q 'serviceAccountName: default' "$NOSA" || fail "deployment should fall back to the default ServiceAccount"

echo "All Helm chart checks passed."
