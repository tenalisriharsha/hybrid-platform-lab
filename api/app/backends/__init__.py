"""Provisioning backend registry.

Each backend turns an Environment into (or out of) real infrastructure.
Phase 1 ships only SimulatedBackend so the API is fully usable end to end;
later phases replace individual backends without touching the router:

- Phase 2 gives "vsphere" a real implementation that calls the PowerCLI
  module through pwsh (New-LabVM / removes the VM it created).
- Phase 3 gives "proxmox" and "azure" real implementations that render
  Terraform tfvars and run `terraform plan` only - never apply.
"""

from __future__ import annotations

from app.backends.base import ProvisioningBackend, ProvisioningError
from app.backends.simulated import SimulatedBackend

_BACKENDS: dict[str, ProvisioningBackend] = {
    "vsphere": SimulatedBackend("vsphere"),
    "proxmox": SimulatedBackend("proxmox"),
    "azure": SimulatedBackend("azure"),
}


def get_backend(name: str) -> ProvisioningBackend:
    try:
        return _BACKENDS[name]
    except KeyError as exc:
        raise ProvisioningError(f"no backend registered for {name!r}") from exc


__all__ = ["ProvisioningBackend", "ProvisioningError", "get_backend"]
