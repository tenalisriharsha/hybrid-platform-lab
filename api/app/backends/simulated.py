from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from app.backends.base import ProvisioningBackend, ProvisionResult


class SimulatedBackend(ProvisioningBackend):
    """Placeholder backend used until a real one is wired in.

    It never touches real infrastructure. It exists so every /environments
    request has somewhere to go in Phase 1, before the vSphere (Phase 2) and
    Proxmox/Azure (Phase 3) backends replace it.
    """

    def __init__(self, kind: str) -> None:
        self._kind = kind

    def provision(
        self, *, name: str, template: str, size: str, owner: str, expiry: datetime
    ) -> ProvisionResult:
        return ProvisionResult(
            backend_ref=f"sim-{self._kind}-{uuid4().hex[:12]}",
            detail=f"simulated {self._kind} backend; no real infrastructure was touched",
        )

    def deprovision(self, *, backend_ref: str) -> None:
        return None
