"""The Azure backend: renders a tfvars file and runs `terraform plan` against
terraform/environments/dev/azure - it never runs `terraform apply`, so no
real Azure resource group or VM is ever created. deprovision() is a no-op
for exactly that reason: there is no real resource to tear down.

Credentials come entirely from environment variables, translated to the
standard ARM_* names the azurerm provider itself reads (so a client secret
never gets written into a tfvars file or passed as a CLI argument - the
provider block in terraform/environments/dev/azure/main.tf has no explicit
credentials, relying on these).
"""

from __future__ import annotations

import os
from datetime import datetime

from app.backends import terraform_utils
from app.backends.base import ProvisioningBackend, ProvisioningError, ProvisionResult
from app.catalog import TEMPLATES

_SIZE_TO_VM_SIZE = {
    "small": "Standard_B2s",
    "medium": "Standard_B4ms",
    "large": "Standard_D4s_v5",
}


class AzureBackend(ProvisioningBackend):
    """Plans (never applies) Azure Linux VMs via the azure-vm Terraform module."""

    def _config(self) -> dict[str, str]:
        required = (
            "HYBRID_LAB_AZURE_SUBSCRIPTION_ID",
            "HYBRID_LAB_AZURE_TENANT_ID",
            "HYBRID_LAB_AZURE_CLIENT_ID",
            "HYBRID_LAB_AZURE_CLIENT_SECRET",
            "HYBRID_LAB_AZURE_LOCATION",
            "HYBRID_LAB_AZURE_SSH_PUBLIC_KEY",
        )
        missing = [name for name in required if not os.environ.get(name)]
        if missing:
            raise ProvisioningError(f"azure backend is not configured: missing {', '.join(missing)}")
        return {name: os.environ[name] for name in required}

    def provision(
        self, *, name: str, template: str, size: str, owner: str, expiry: datetime
    ) -> ProvisionResult:
        config = self._config()
        image = TEMPLATES[template]["azure_image"]
        vm_size = _SIZE_TO_VM_SIZE[size]

        tfvars_path = terraform_utils.render_tfvars_file(
            {
                "name": name,
                "location": config["HYBRID_LAB_AZURE_LOCATION"],
                "vm_size": vm_size,
                "ssh_public_key": config["HYBRID_LAB_AZURE_SSH_PUBLIC_KEY"],
                "image_publisher": image["publisher"],
                "image_offer": image["offer"],
                "image_sku": image["sku"],
                "image_version": image["version"],
                "owner": owner,
                "expiry": expiry.isoformat(),
            }
        )
        env = {
            **os.environ,
            "ARM_SUBSCRIPTION_ID": config["HYBRID_LAB_AZURE_SUBSCRIPTION_ID"],
            "ARM_TENANT_ID": config["HYBRID_LAB_AZURE_TENANT_ID"],
            "ARM_CLIENT_ID": config["HYBRID_LAB_AZURE_CLIENT_ID"],
            "ARM_CLIENT_SECRET": config["HYBRID_LAB_AZURE_CLIENT_SECRET"],
        }

        stdout = terraform_utils.plan(terraform_utils.environment_dir("azure"), tfvars_path, env)
        summary = terraform_utils.plan_summary(stdout)

        return ProvisionResult(
            backend_ref=f"tf-plan-azure-{name}",
            detail=f"terraform plan only ({vm_size}, image {image['offer']}/{image['sku']}): {summary}",
        )

    def deprovision(self, *, backend_ref: str) -> None:
        # provision() never ran `terraform apply`, so there is no real VM
        # behind backend_ref to destroy - nothing to do.
        return None
