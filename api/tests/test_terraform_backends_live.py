"""Live integration test: runs the *real* terraform binary (no mocked
subprocess) through the Proxmox backend's exact code path - init, render a
tfvars file, plan, parse the summary. There is no local Proxmox simulator
available in this environment, so credentials point nowhere real; that
turns out not to matter, because `terraform plan` for a brand-new resource
never contacts the Proxmox API at all (there is nothing existing to refresh,
and the provider defers connecting until an actual create/apply) - verified
manually before writing this test. So this test asserts the plan genuinely
succeeds end to end through real terraform, not that it fails; it is the
Python-level equivalent of the module-level `terraform test` suites.
Skipped automatically when terraform isn't on PATH.
"""

from __future__ import annotations

import shutil
from datetime import UTC, datetime, timedelta

import pytest

from app.backends.proxmox import ProxmoxBackend

pytestmark = pytest.mark.skipif(
    shutil.which("terraform") is None, reason="requires the terraform CLI for a live plan"
)


def test_provision_runs_a_real_terraform_plan(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_ENDPOINT", "https://127.0.0.1:19")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_API_TOKEN", "pytest@pve!token=not-real")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_NODE", "pve1")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_INSECURE", "true")

    backend = ProxmoxBackend()
    result = backend.provision(
        name="pytest-live",
        template="ubuntu-22.04-proxmox",
        size="small",
        owner="pytest@example.com",
        expiry=datetime.now(UTC) + timedelta(hours=1),
    )

    assert result.backend_ref == "tf-plan-proxmox-pytest-live"
    assert "1 to add, 0 to change, 0 to destroy" in result.detail

    # Deliberately no real resource was ever created (terraform apply never
    # ran), so deprovisioning it back is a no-op - nothing to assert beyond
    # "it doesn't raise".
    backend.deprovision(backend_ref=result.backend_ref)
