"""The vSphere backend: shells out to pwsh and calls the HybridLab PowerCLI module.

Connection details and template-to-source-VM mapping come entirely from environment
variables - this module never hardcodes a real vCenter's credentials or template names.
HYBRID_LAB_VSPHERE_TEMPLATE_OVERRIDES (a JSON object) lets a deployment (or an
integration test, against vcsim) point a catalog template at a different source VM
than catalog.py's placeholder default (e.g. an actual vcsim fixture VM name).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

from app.backends.base import ProvisioningBackend, ProvisioningError, ProvisionResult
from app.catalog import TEMPLATES

_REPO_ROOT = Path(__file__).resolve().parents[3]
_DEFAULT_MODULE_PATH = _REPO_ROOT / "powercli" / "HybridLab"
_SCRIPTS_DIR = _REPO_ROOT / "powercli" / "scripts"
_PROVISION_SCRIPT = _SCRIPTS_DIR / "Invoke-VSphereProvision.ps1"
_DEPROVISION_SCRIPT = _SCRIPTS_DIR / "Invoke-VSphereDeprovision.ps1"

# Connect-VIServer plus Import-Module/pwsh startup routinely takes 30-90s against a
# simulated server, so this allows comfortable headroom above that rather than the
# couple of seconds the actual clone/remove operation itself needs.
_SUBPROCESS_TIMEOUT_SECONDS = 180


class VSphereBackend(ProvisioningBackend):
    """Provisions and removes vSphere VMs via pwsh + the HybridLab module."""

    def _connection(self) -> dict[str, str]:
        required = ("HYBRID_LAB_VSPHERE_SERVER", "HYBRID_LAB_VSPHERE_USER", "HYBRID_LAB_VSPHERE_PASSWORD")
        missing = [name for name in required if not os.environ.get(name)]
        if missing:
            raise ProvisioningError(f"vSphere backend is not configured: missing {', '.join(missing)}")
        return {
            "server": os.environ["HYBRID_LAB_VSPHERE_SERVER"],
            "port": os.environ.get("HYBRID_LAB_VSPHERE_PORT", "443"),
            "user": os.environ["HYBRID_LAB_VSPHERE_USER"],
        }

    def _source_vm(self, template: str) -> str:
        raw_overrides = os.environ.get("HYBRID_LAB_VSPHERE_TEMPLATE_OVERRIDES")
        if raw_overrides:
            try:
                overrides = json.loads(raw_overrides)
            except json.JSONDecodeError as exc:
                raise ProvisioningError(f"invalid HYBRID_LAB_VSPHERE_TEMPLATE_OVERRIDES: {exc}") from exc
            if template in overrides:
                return overrides[template]
        return TEMPLATES[template]["source_vm"]

    def _pwsh_path(self) -> str:
        pwsh = shutil.which("pwsh")
        if pwsh is None:
            raise ProvisioningError("pwsh is not installed/available on PATH")
        return pwsh

    def _run(self, script: Path, args: list[str]) -> str:
        completed = subprocess.run(
            [self._pwsh_path(), "-NoLogo", "-NonInteractive", "-File", str(script), *args],
            capture_output=True,
            text=True,
            timeout=_SUBPROCESS_TIMEOUT_SECONDS,
        )
        if completed.returncode != 0:
            raise ProvisioningError(
                f"{script.name} exited {completed.returncode}: "
                f"{completed.stderr.strip() or completed.stdout.strip()}"
            )
        return completed.stdout

    def provision(
        self, *, name: str, template: str, size: str, owner: str, expiry: datetime
    ) -> ProvisionResult:
        conn = self._connection()
        source_vm = self._source_vm(template)
        port_group = os.environ.get("HYBRID_LAB_VSPHERE_PORTGROUP", "VM Network")
        module_path = os.environ.get("HYBRID_LAB_VSPHERE_MODULE_PATH", str(_DEFAULT_MODULE_PATH))

        stdout = self._run(
            _PROVISION_SCRIPT,
            [
                "-Server", conn["server"],
                "-Port", conn["port"],
                "-User", conn["user"],
                "-ModulePath", module_path,
                "-TemplateName", source_vm,
                "-Name", name,
                "-PortGroup", port_group,
                "-Owner", owner,
                "-Expiry", expiry.isoformat(),
            ],
        )

        try:
            payload = json.loads(stdout.strip().splitlines()[-1])
        except (ValueError, IndexError) as exc:
            raise ProvisioningError(f"could not parse New-LabVM output: {stdout!r}") from exc

        return ProvisionResult(
            backend_ref=payload["Id"],
            detail=f"cloned from vSphere template '{source_vm}' (vm id {payload['Id']})",
        )

    def deprovision(self, *, backend_ref: str) -> None:
        conn = self._connection()
        self._run(
            _DEPROVISION_SCRIPT,
            [
                "-Server", conn["server"],
                "-Port", conn["port"],
                "-User", conn["user"],
                "-BackendRef", backend_ref,
            ],
        )
