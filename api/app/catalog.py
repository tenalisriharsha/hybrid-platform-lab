"""Approved templates and sizes.

Requests are only accepted for a template and size listed here. Each template
maps to exactly one provisioning backend, so the backend is never chosen by
the caller - it is derived from the template.
"""

from __future__ import annotations

from typing import Literal

Backend = Literal["vsphere", "proxmox", "azure"]

TEMPLATES: dict[str, dict[str, object]] = {
    "ubuntu-22.04-vsphere": {
        "backend": "vsphere",
        "os": "linux",
        "description": "Ubuntu 22.04 LTS, cloned from a vSphere template VM.",
        "source_vm": "tpl-ubuntu-2204",
    },
    "windows-server-2022-vsphere": {
        "backend": "vsphere",
        "os": "windows",
        "description": "Windows Server 2022, cloned from a vSphere template VM.",
        "source_vm": "tpl-windows-server-2022",
    },
    "ubuntu-22.04-proxmox": {
        "backend": "proxmox",
        "os": "linux",
        "description": "Ubuntu 22.04 LTS on Proxmox VE, via the proxmox-vm Terraform module.",
        # VMID of the Proxmox template to clone - a placeholder a real deployment
        # overrides (see HYBRID_LAB_PROXMOX_TEMPLATE_OVERRIDES).
        "proxmox_template_vm_id": 9000,
    },
    "ubuntu-22.04-azure": {
        "backend": "azure",
        "os": "linux",
        "description": "Ubuntu 22.04 LTS on Azure, via the azure-vm Terraform module.",
        "azure_image": {
            "publisher": "Canonical",
            "offer": "0001-com-ubuntu-server-jammy",
            "sku": "22_04-lts-gen2",
            "version": "latest",
        },
    },
}

SIZES: dict[str, dict[str, int]] = {
    "small": {"cpu": 2, "memory_gb": 4, "disk_gb": 40},
    "medium": {"cpu": 4, "memory_gb": 8, "disk_gb": 80},
    "large": {"cpu": 8, "memory_gb": 16, "disk_gb": 160},
}

DEFAULT_TTL_HOURS = 24
MAX_TTL_HOURS = 24 * 7


def backend_for_template(template: str) -> str:
    return TEMPLATES[template]["backend"]
