"""Unit tests for the Proxmox backend's own logic (env validation, tfvars
rendering, template overrides, error mapping) with terraform_utils.plan
mocked out. These do not need a real terraform binary or Proxmox cluster -
that's what test_terraform_backends_live.py is for.
"""

from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from pathlib import Path

import pytest

from app.backends.base import ProvisioningError
from app.backends.proxmox import ProxmoxBackend


@pytest.fixture()
def clean_proxmox_env(monkeypatch: pytest.MonkeyPatch) -> pytest.MonkeyPatch:
    for key in list(os.environ):
        if key.startswith("HYBRID_LAB_PROXMOX_"):
            monkeypatch.delenv(key, raising=False)
    return monkeypatch


def _configure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_ENDPOINT", "https://pve.test:8006")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_API_TOKEN", "user@pve!token=secret")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_NODE", "pve1")


def test_provision_requires_connection_env(clean_proxmox_env: pytest.MonkeyPatch) -> None:
    backend = ProxmoxBackend()
    with pytest.raises(ProvisioningError, match="not configured"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-proxmox", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_provision_renders_expected_tfvars_and_result(clean_proxmox_env: pytest.MonkeyPatch) -> None:
    _configure(clean_proxmox_env)

    captured: dict[str, object] = {}

    def fake_plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
        captured["env_dir"] = env_dir
        captured["tfvars"] = json.loads(tfvars_path.read_text())
        captured["proxmox_env"] = env
        return "Plan: 1 to add, 0 to change, 0 to destroy."

    clean_proxmox_env.setattr("app.backends.proxmox.terraform_utils.plan", fake_plan)

    backend = ProxmoxBackend()
    expiry = datetime(2099, 1, 1, tzinfo=UTC)
    result = backend.provision(
        name="dev-1", template="ubuntu-22.04-proxmox", size="small", owner="a@example.com", expiry=expiry
    )

    assert str(captured["env_dir"]).endswith("terraform/environments/dev/proxmox")
    assert captured["tfvars"] == {
        "name": "dev-1",
        "target_node": "pve1",
        "template_vm_id": 9000,
        "cpu_cores": 2,
        "memory_mb": 4096,
        "disk_gb": 40,
        "owner": "a@example.com",
        "expiry": expiry.isoformat(),
    }
    assert captured["proxmox_env"]["PROXMOX_VE_ENDPOINT"] == "https://pve.test:8006"
    assert captured["proxmox_env"]["PROXMOX_VE_API_TOKEN"] == "user@pve!token=secret"

    assert result.backend_ref == "tf-plan-proxmox-dev-1"
    assert "9000" in result.detail
    assert "1 to add" in result.detail


def test_provision_uses_template_override(clean_proxmox_env: pytest.MonkeyPatch) -> None:
    _configure(clean_proxmox_env)
    clean_proxmox_env.setenv(
        "HYBRID_LAB_PROXMOX_TEMPLATE_OVERRIDES", json.dumps({"ubuntu-22.04-proxmox": 1234})
    )

    captured: dict[str, object] = {}

    def fake_plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
        captured["tfvars"] = json.loads(tfvars_path.read_text())
        return "Plan: 1 to add, 0 to change, 0 to destroy."

    clean_proxmox_env.setattr("app.backends.proxmox.terraform_utils.plan", fake_plan)

    backend = ProxmoxBackend()
    backend.provision(
        name="dev-1", template="ubuntu-22.04-proxmox", size="small", owner="a@example.com",
        expiry=datetime.now(UTC),
    )

    assert captured["tfvars"]["template_vm_id"] == 1234


def test_provision_propagates_plan_failure(clean_proxmox_env: pytest.MonkeyPatch) -> None:
    _configure(clean_proxmox_env)

    def fake_plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
        raise ProvisioningError("terraform plan failed: connection refused")

    clean_proxmox_env.setattr("app.backends.proxmox.terraform_utils.plan", fake_plan)

    backend = ProxmoxBackend()
    with pytest.raises(ProvisioningError, match="connection refused"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-proxmox", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_deprovision_is_a_noop(clean_proxmox_env: pytest.MonkeyPatch) -> None:
    def fail_plan(*args: object, **kwargs: object) -> str:
        raise AssertionError("deprovision should never call terraform plan")

    clean_proxmox_env.setattr("app.backends.proxmox.terraform_utils.plan", fail_plan)

    backend = ProxmoxBackend()
    assert backend.deprovision(backend_ref="tf-plan-proxmox-dev-1") is None
