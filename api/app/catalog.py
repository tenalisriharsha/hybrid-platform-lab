"""Approved templates and sizes.

Requests are only accepted for a template and size listed here. Each template
maps to exactly one provisioning backend, so the backend is never chosen by
the caller - it is derived from the template.
"""

from __future__ import annotations

from typing import Literal

Backend = Literal["vsphere", "proxmox", "azure"]

TEMPLATES: dict[str, dict[str, str]] = {
    "ubuntu-22.04-vsphere": {
        "backend": "vsphere",
        "os": "linux",
        "description": "Ubuntu 22.04 LTS, cloned from a vSphere template VM.",
    },
    "windows-server-2022-vsphere": {
        "backend": "vsphere",
        "os": "windows",
        "description": "Windows Server 2022, cloned from a vSphere template VM.",
    },
    "ubuntu-22.04-proxmox": {
        "backend": "proxmox",
        "os": "linux",
        "description": "Ubuntu 22.04 LTS on Proxmox VE, via the proxmox-vm Terraform module.",
    },
    "ubuntu-22.04-azure": {
        "backend": "azure",
        "os": "linux",
        "description": "Ubuntu 22.04 LTS on Azure, via the azure-vm Terraform module.",
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
