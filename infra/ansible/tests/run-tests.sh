#!/usr/bin/env bash
# Test layer for infra/ansible: ansible-lint, then a real exercise of the
# platform_config role (check-mode dry run, a real run, and an idempotency
# check), all against localhost with ansible_connection=local. No real hosts
# are configured — the playbook only renders local config files under
# dist/config/, which this script always cleans up on exit.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUTPUT_DIR="$(pwd)/dist/config/lab"
PLAYBOOK="playbooks/configure-platform.yml"
WORK=$(mktemp -d)

cleanup() {
  rm -rf "$OUTPUT_DIR" "$WORK"
}
trap cleanup EXIT

echo "==> ansible-lint"
ansible-lint . </dev/null

echo "==> Ensuring a clean starting state"
rm -rf "$OUTPUT_DIR"
[ ! -e "$OUTPUT_DIR" ] || { echo "FAIL: $OUTPUT_DIR should not exist before the test"; exit 1; }

echo "==> Check-mode dry run (no files should be written)"
ansible-playbook "$PLAYBOOK" --check --diff </dev/null | tee "$WORK/check.log"
grep -q "changed=3" "$WORK/check.log" || { echo "FAIL: expected 3 changed tasks in check mode (dir + 2 templates)"; exit 1; }
[ ! -e "$OUTPUT_DIR/application.yml" ] || { echo "FAIL: check mode must not write application.yml"; exit 1; }
[ ! -e "$OUTPUT_DIR/hybrid-platform-sync.json" ] || { echo "FAIL: check mode must not write hybrid-platform-sync.json"; exit 1; }
echo "PASS: check mode reported the expected changes without writing anything."

echo "==> Real run"
ansible-playbook "$PLAYBOOK" </dev/null | tee "$WORK/apply.log"
grep -q "changed=3" "$WORK/apply.log" || { echo "FAIL: expected 3 changed tasks on the real run"; exit 1; }

test -f "$OUTPUT_DIR/application.yml" || { echo "FAIL: application.yml was not rendered"; exit 1; }
test -f "$OUTPUT_DIR/hybrid-platform-sync.json" || { echo "FAIL: hybrid-platform-sync.json was not rendered"; exit 1; }

grep -q "port: 8080" "$OUTPUT_DIR/application.yml" || { echo "FAIL: application.yml missing expected server port"; exit 1; }
python3 -c "
import json
with open('$OUTPUT_DIR/hybrid-platform-sync.json') as f:
    cfg = json.load(f)
assert cfg['environment'] == 'lab', cfg
assert cfg['vcsim']['port'] == 8989, cfg
assert cfg['sync']['intervalSeconds'] == 300, cfg
"
echo "PASS: rendered config files have the expected content."

echo "==> Idempotency: running again should report no changes"
ansible-playbook "$PLAYBOOK" </dev/null | tee "$WORK/rerun.log"
grep -q "changed=0" "$WORK/rerun.log" || { echo "FAIL: second run should be a no-op (changed=0)"; exit 1; }
echo "PASS: second run was idempotent."

echo "==> Overriding variables produces different, still-valid output"
ansible-playbook "$PLAYBOOK" -e "platform_config_env=staging platform_config_api_port=9090" </dev/null | tee "$WORK/override.log"
grep -q "port: 9090" "$WORK/../dist/config/staging/application.yml" 2>/dev/null \
  || grep -q "port: 9090" "$(pwd)/dist/config/staging/application.yml" \
  || { echo "FAIL: overridden platform_config_api_port did not take effect"; exit 1; }
rm -rf "$(pwd)/dist/config/staging"
echo "PASS: variable overrides render a distinct environment config."

echo "==> Rejects an out-of-range variable"
if ansible-playbook "$PLAYBOOK" -e "platform_config_sync_interval_seconds=5" </dev/null > "$WORK/invalid.log" 2>&1; then
  echo "FAIL: playbook should have failed validation for sync_interval_seconds=5"
  cat "$WORK/invalid.log"
  exit 1
fi
grep -q "Invalid platform_config variables" "$WORK/invalid.log" || { echo "FAIL: expected the assert failure message"; cat "$WORK/invalid.log"; exit 1; }
echo "PASS: invalid input is rejected by the role's assert task."

echo "ALL ANSIBLE TESTS PASSED"
