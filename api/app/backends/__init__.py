"""Provisioning backend registry.

Each backend turns an Environment into (or out of) real infrastructure.
Phase 1 shipped only SimulatedBackend so the API was fully usable end to end;
later phases replace individual backends without touching the router:

- Phase 2 gives "vsphere" a real implementation that calls the PowerCLI
  module through pwsh (New-LabVM / removes the VM it created). It requires
  HYBRID_LAB_VSPHERE_SERVER/_USER/_PASSWORD to be set - see
  app/backends/vsphere.py - and falls back to SimulatedBackend when they
  aren't, so the API stays usable without a real (or vcsim) vCenter.
- Phase 3 gives "proxmox" and "azure" real implementations that render
  Terraform tfvars and run `terraform plan` only - never apply.
"""

from __future__ import annotations

import os

from app.backends.base import ProvisioningBackend, ProvisioningError
from app.backends.simulated import SimulatedBackend
from app.backends.vsphere import VSphereBackend


def _vsphere_backend() -> ProvisioningBackend:
    if os.environ.get("HYBRID_LAB_VSPHERE_SERVER"):
        return VSphereBackend()
    return SimulatedBackend("vsphere")


_BACKENDS: dict[str, ProvisioningBackend] = {
    "vsphere": _vsphere_backend(),
    "proxmox": SimulatedBackend("proxmox"),
    "azure": SimulatedBackend("azure"),
}


def get_backend(name: str) -> ProvisioningBackend:
    try:
        return _BACKENDS[name]
    except KeyError as exc:
        raise ProvisioningError(f"no backend registered for {name!r}") from exc


__all__ = ["ProvisioningBackend", "ProvisioningError", "get_backend"]
