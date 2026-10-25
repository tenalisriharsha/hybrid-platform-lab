"""The Proxmox backend: renders a tfvars file and runs `terraform plan`
against terraform/environments/dev/proxmox - it never runs `terraform apply`,
so no real Proxmox VM is ever created. deprovision() is a no-op for exactly
that reason: there is no real resource to tear down.

Connection details come entirely from environment variables, translated to
the PROXMOX_VE_* names the bpg/proxmox provider itself reads (so a token
never gets written into a tfvars file or passed as a CLI argument - the
provider block in terraform/environments/dev/proxmox/main.tf is deliberately
empty, relying on these). HYBRID_LAB_PROXMOX_TEMPLATE_OVERRIDES (a JSON
object) lets a deployment point a catalog template at a different source
VMID than catalog.py's placeholder default.
"""

from __future__ import annotations

import json
import os
from datetime import datetime

from app.backends import terraform_utils
from app.backends.base import ProvisioningBackend, ProvisioningError, ProvisionResult
from app.catalog import SIZES, TEMPLATES


class ProxmoxBackend(ProvisioningBackend):
    """Plans (never applies) Proxmox VM clones via the proxmox-vm Terraform module."""

    def _config(self) -> dict[str, str]:
        required = ("HYBRID_LAB_PROXMOX_ENDPOINT", "HYBRID_LAB_PROXMOX_API_TOKEN", "HYBRID_LAB_PROXMOX_NODE")
        missing = [name for name in required if not os.environ.get(name)]
        if missing:
            raise ProvisioningError(f"proxmox backend is not configured: missing {', '.join(missing)}")
        return {
            "endpoint": os.environ["HYBRID_LAB_PROXMOX_ENDPOINT"],
            "api_token": os.environ["HYBRID_LAB_PROXMOX_API_TOKEN"],
            "node": os.environ["HYBRID_LAB_PROXMOX_NODE"],
            "insecure": os.environ.get("HYBRID_LAB_PROXMOX_INSECURE", "false"),
        }

    def _template_vm_id(self, template: str) -> int:
        raw_overrides = os.environ.get("HYBRID_LAB_PROXMOX_TEMPLATE_OVERRIDES")
        if raw_overrides:
            try:
                overrides = json.loads(raw_overrides)
            except json.JSONDecodeError as exc:
                raise ProvisioningError(f"invalid HYBRID_LAB_PROXMOX_TEMPLATE_OVERRIDES: {exc}") from exc
            if template in overrides:
                return int(overrides[template])
        return int(TEMPLATES[template]["proxmox_template_vm_id"])

    def provision(
        self, *, name: str, template: str, size: str, owner: str, expiry: datetime
    ) -> ProvisionResult:
        config = self._config()
        template_vm_id = self._template_vm_id(template)
        spec = SIZES[size]

        tfvars_path = terraform_utils.render_tfvars_file(
            {
                "name": name,
                "target_node": config["node"],
                "template_vm_id": template_vm_id,
                "cpu_cores": spec["cpu"],
                "memory_mb": spec["memory_gb"] * 1024,
                "disk_gb": spec["disk_gb"],
                "owner": owner,
                "expiry": expiry.isoformat(),
            }
        )
        env = {
            **os.environ,
            "PROXMOX_VE_ENDPOINT": config["endpoint"],
            "PROXMOX_VE_API_TOKEN": config["api_token"],
            "PROXMOX_VE_INSECURE": config["insecure"],
        }

        stdout = terraform_utils.plan(
            terraform_utils.environment_dir("proxmox"), tfvars_path, env
        )
        summary = terraform_utils.plan_summary(stdout)

        return ProvisionResult(
            backend_ref=f"tf-plan-proxmox-{name}",
            detail=f"terraform plan only (clone of template VMID {template_vm_id}): {summary}",
        )

    def deprovision(self, *, backend_ref: str) -> None:
        # provision() never ran `terraform apply`, so there is no real VM
        # behind backend_ref to destroy - nothing to do.
        return None
