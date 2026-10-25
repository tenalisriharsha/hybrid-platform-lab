#!/usr/bin/env bash
# Starts a vcsim container in vCenter mode and one in standalone-ESXi mode, runs the
# PowerCLI Pester suite against both, and always tears the containers down afterwards.
set -euo pipefail

VCENTER_CONTAINER="hpl-vcsim-vcenter"
ESXI_CONTAINER="hpl-vcsim-esxi"
VCENTER_PORT="${HPL_VCSIM_VCENTER_PORT:-8989}"
ESXI_PORT="${HPL_VCSIM_ESXI_PORT:-8990}"

cleanup() {
  docker rm -f "$VCENTER_CONTAINER" "$ESXI_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
docker run -d --name "$VCENTER_CONTAINER" -p "${VCENTER_PORT}:8989" vmware/vcsim -l :8989 >/dev/null
docker run -d --name "$ESXI_CONTAINER" -p "${ESXI_PORT}:8989" vmware/vcsim -l :8989 -esx >/dev/null

echo "Waiting for vcsim containers to accept connections..."
for port in "$VCENTER_PORT" "$ESXI_PORT"; do
  for _ in $(seq 1 30); do
    if curl -skf -o /dev/null -w '' "https://127.0.0.1:${port}/sdk" 2>/dev/null; then
      break
    fi
    code="$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1:${port}/sdk" 2>/dev/null || echo 000)"
    if [ "$code" != "000" ]; then
      break
    fi
    sleep 0.5
  done
done

export HPL_VCSIM_VCENTER_PORT="$VCENTER_PORT"
export HPL_VCSIM_ESXI_PORT="$ESXI_PORT"

cd "$(dirname "$0")/.."
pwsh -NoLogo -NonInteractive -Command "
\$config = New-PesterConfiguration
\$config.Run.Path = './powercli/Tests'
\$config.Run.Exit = \$true
\$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration \$config
"
