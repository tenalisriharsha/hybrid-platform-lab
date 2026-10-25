"""Unit tests for the Azure backend's own logic (env validation, tfvars
rendering, size mapping, error mapping) with terraform_utils.plan mocked
out. These do not need a real terraform binary or Azure subscription -
that's what test_terraform_backends_live.py is for.
"""

from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from pathlib import Path

import pytest

from app.backends.azure import AzureBackend
from app.backends.base import ProvisioningError


@pytest.fixture()
def clean_azure_env(monkeypatch: pytest.MonkeyPatch) -> pytest.MonkeyPatch:
    for key in list(os.environ):
        if key.startswith("HYBRID_LAB_AZURE_"):
            monkeypatch.delenv(key, raising=False)
    return monkeypatch


def _configure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HYBRID_LAB_AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
    monkeypatch.setenv("HYBRID_LAB_AZURE_TENANT_ID", "11111111-1111-1111-1111-111111111111")
    monkeypatch.setenv("HYBRID_LAB_AZURE_CLIENT_ID", "22222222-2222-2222-2222-222222222222")
    monkeypatch.setenv("HYBRID_LAB_AZURE_CLIENT_SECRET", "s3cret")
    monkeypatch.setenv("HYBRID_LAB_AZURE_LOCATION", "eastus")
    monkeypatch.setenv(
        "HYBRID_LAB_AZURE_SSH_PUBLIC_KEY",
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoKvgDQioDGxNPCnokvwiY9yAIxOjLXWz1j8MXnlTI7 hybrid-lab",
    )


def test_provision_requires_connection_env(clean_azure_env: pytest.MonkeyPatch) -> None:
    backend = AzureBackend()
    with pytest.raises(ProvisioningError, match="not configured"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-azure", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_provision_renders_expected_tfvars_and_result(clean_azure_env: pytest.MonkeyPatch) -> None:
    _configure(clean_azure_env)
    ssh_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoKvgDQioDGxNPCnokvwiY9yAIxOjLXWz1j8MXnlTI7 hybrid-lab"

    captured: dict[str, object] = {}

    def fake_plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
        captured["env_dir"] = env_dir
        captured["tfvars"] = json.loads(tfvars_path.read_text())
        captured["arm_env"] = env
        return "Plan: 4 to add, 0 to change, 0 to destroy."

    clean_azure_env.setattr("app.backends.azure.terraform_utils.plan", fake_plan)

    backend = AzureBackend()
    expiry = datetime(2099, 1, 1, tzinfo=UTC)
    result = backend.provision(
        name="dev-1", template="ubuntu-22.04-azure", size="medium", owner="a@example.com", expiry=expiry
    )

    assert str(captured["env_dir"]).endswith("terraform/environments/dev/azure")
    assert captured["tfvars"] == {
        "name": "dev-1",
        "location": "eastus",
        "vm_size": "Standard_B4ms",
        "ssh_public_key": ssh_key,
        "image_publisher": "Canonical",
        "image_offer": "0001-com-ubuntu-server-jammy",
        "image_sku": "22_04-lts-gen2",
        "image_version": "latest",
        "owner": "a@example.com",
        "expiry": expiry.isoformat(),
    }
    assert captured["arm_env"]["ARM_SUBSCRIPTION_ID"] == "00000000-0000-0000-0000-000000000000"
    assert captured["arm_env"]["ARM_CLIENT_SECRET"] == "s3cret"

    assert result.backend_ref == "tf-plan-azure-dev-1"
    assert "Standard_B4ms" in result.detail
    assert "4 to add" in result.detail


@pytest.mark.parametrize(
    ("size", "vm_size"),
    [("small", "Standard_B2s"), ("medium", "Standard_B4ms"), ("large", "Standard_D4s_v5")],
)
def test_size_maps_to_expected_vm_size(clean_azure_env: pytest.MonkeyPatch, size: str, vm_size: str) -> None:
    _configure(clean_azure_env)
    captured: dict[str, object] = {}

    def fake_plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
        captured["tfvars"] = json.loads(tfvars_path.read_text())
        return "Plan: 4 to add, 0 to change, 0 to destroy."

    clean_azure_env.setattr("app.backends.azure.terraform_utils.plan", fake_plan)

    backend = AzureBackend()
    backend.provision(
        name="dev-1", template="ubuntu-22.04-azure", size=size, owner="a@example.com",
        expiry=datetime.now(UTC),
    )

    assert captured["tfvars"]["vm_size"] == vm_size


def test_provision_propagates_plan_failure(clean_azure_env: pytest.MonkeyPatch) -> None:
    _configure(clean_azure_env)

    def fake_plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
        raise ProvisioningError("terraform plan failed: authentication failed")

    clean_azure_env.setattr("app.backends.azure.terraform_utils.plan", fake_plan)

    backend = AzureBackend()
    with pytest.raises(ProvisioningError, match="authentication failed"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-azure", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_deprovision_is_a_noop(clean_azure_env: pytest.MonkeyPatch) -> None:
    def fail_plan(*args: object, **kwargs: object) -> str:
        raise AssertionError("deprovision should never call terraform plan")

    clean_azure_env.setattr("app.backends.azure.terraform_utils.plan", fail_plan)

    backend = AzureBackend()
    assert backend.deprovision(backend_ref="tf-plan-azure-dev-1") is None
