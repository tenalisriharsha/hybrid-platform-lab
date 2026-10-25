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
  Terraform tfvars and run `terraform plan` only - never apply. They require
  HYBRID_LAB_PROXMOX_*/HYBRID_LAB_AZURE_* respectively - see
  app/backends/proxmox.py and app/backends/azure.py - and fall back to
  SimulatedBackend when they aren't, so the API stays usable without a real
  Proxmox cluster or Azure subscription.
"""

from __future__ import annotations

import os

from app.backends.azure import AzureBackend
from app.backends.base import ProvisioningBackend, ProvisioningError
from app.backends.proxmox import ProxmoxBackend
from app.backends.simulated import SimulatedBackend
from app.backends.vsphere import VSphereBackend


def _vsphere_backend() -> ProvisioningBackend:
    if os.environ.get("HYBRID_LAB_VSPHERE_SERVER"):
        return VSphereBackend()
    return SimulatedBackend("vsphere")


def _proxmox_backend() -> ProvisioningBackend:
    if os.environ.get("HYBRID_LAB_PROXMOX_ENDPOINT"):
        return ProxmoxBackend()
    return SimulatedBackend("proxmox")


def _azure_backend() -> ProvisioningBackend:
    if os.environ.get("HYBRID_LAB_AZURE_SUBSCRIPTION_ID"):
        return AzureBackend()
    return SimulatedBackend("azure")


_BACKENDS: dict[str, ProvisioningBackend] = {
    "vsphere": _vsphere_backend(),
    "proxmox": _proxmox_backend(),
    "azure": _azure_backend(),
}


def get_backend(name: str) -> ProvisioningBackend:
    try:
        return _BACKENDS[name]
    except KeyError as exc:
        raise ProvisioningError(f"no backend registered for {name!r}") from exc


__all__ = ["ProvisioningBackend", "ProvisioningError", "get_backend"]
