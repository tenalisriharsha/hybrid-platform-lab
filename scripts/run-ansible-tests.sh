#!/usr/bin/env bash
# Lints and tests the linux-baseline Ansible role against a real (but
# non-systemd) Docker container, then asserts the second apply is a no-op.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
CONTAINER_NAME="hybrid-lab-ansible-target"
IMAGE="python:3.12-slim"
INVENTORY_FILE="$(mktemp -t hybrid-lab-ansible-inventory.XXXXXX.ini)"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  rm -f "${INVENTORY_FILE}"
}
trap cleanup EXIT

export ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"

echo "==> Installing required Ansible collections"
ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml" >/dev/null

echo "==> Running ansible-lint"
(cd "${ANSIBLE_DIR}" && ansible-lint roles/linux-baseline playbooks/baseline.yml)

echo "==> Starting target container (${IMAGE})"
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker run -d --name "${CONTAINER_NAME}" "${IMAGE}" sleep infinity >/dev/null

echo "==> Waiting for the container to accept exec"
for _ in $(seq 1 30); do
  if docker exec "${CONTAINER_NAME}" python3 --version >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

cat > "${INVENTORY_FILE}" <<EOF
[linux_hosts]
${CONTAINER_NAME} ansible_connection=community.docker.docker ansible_python_interpreter=/usr/local/bin/python3

[linux_hosts:vars]
linux_baseline_manage_services=false
ansible_become=false
EOF

echo "==> First apply (expect changes)"
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/playbooks/baseline.yml" \
  | tee /tmp/hybrid-lab-ansible-run1.log

if grep -qE "unreachable=[1-9]|failed=[1-9]" /tmp/hybrid-lab-ansible-run1.log; then
  echo "First apply reported unreachable/failed hosts" >&2
  exit 1
fi

echo "==> Second apply (expect no changes - idempotence check)"
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/playbooks/baseline.yml" \
  | tee /tmp/hybrid-lab-ansible-run2.log

if grep -qE "unreachable=[1-9]|failed=[1-9]" /tmp/hybrid-lab-ansible-run2.log; then
  echo "Second apply reported unreachable/failed hosts" >&2
  exit 1
fi

if ! grep -qE "changed=0" /tmp/hybrid-lab-ansible-run2.log; then
  echo "Second apply was not a no-op (expected changed=0)" >&2
  exit 1
fi

echo "==> linux-baseline role is idempotent"
