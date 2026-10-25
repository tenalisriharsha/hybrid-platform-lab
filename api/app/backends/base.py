from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime


class ProvisioningError(RuntimeError):
    """Raised when a backend cannot provision or destroy an environment."""


@dataclass
class ProvisionResult:
    backend_ref: str
    detail: str


class ProvisioningBackend(ABC):
    """A backend turns an Environment request into (or out of) infrastructure."""

    @abstractmethod
    def provision(
        self, *, name: str, template: str, size: str, owner: str, expiry: datetime
    ) -> ProvisionResult: ...

    @abstractmethod
    def deprovision(self, *, backend_ref: str) -> None: ...
