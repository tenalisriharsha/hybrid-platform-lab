"""Regression tests for issue #19: backend selection must not be frozen at
the moment `app.backends` is first imported.

By the time any test in this file runs, `app.backends` has already been
imported once (transitively, via the `client`/conftest import chain) with
none of the HYBRID_LAB_* variables set - exactly the "import happened before
credentials were configured" scenario the issue describes. Each test then
sets the required variables via monkeypatch and makes a single request,
and expects the *real* backend to be used for that request regardless of
what the environment looked like at import time. Before the fix, get_backend()
returns the SimulatedBackend instance that was captured once at import, so
these fail with a `sim-<backend>-...` backend_ref instead of a real one.
"""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient


def test_proxmox_backend_activates_once_env_vars_are_set_after_import(
    client: TestClient, valid_payload: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_ENDPOINT", "https://pve.test:8006")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_API_TOKEN", "user@pve!token=secret")
    monkeypatch.setenv("HYBRID_LAB_PROXMOX_NODE", "pve1")
    monkeypatch.setattr(
        "app.backends.proxmox.terraform_utils.plan",
        lambda env_dir, tfvars_path, env: "Plan: 1 to add, 0 to change, 0 to destroy.",
    )

    valid_payload["template"] = "ubuntu-22.04-proxmox"
    response = client.post("/environments", json=valid_payload)

    assert response.status_code == 201
    body = response.json()
    assert body["backend"] == "proxmox"
    assert body["backend_ref"].startswith("tf-plan-proxmox-"), body
    assert "simulated" not in body["detail"]


def test_azure_backend_activates_once_env_vars_are_set_after_import(
    client: TestClient, valid_payload: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("HYBRID_LAB_AZURE_SUBSCRIPTION_ID", "sub-123")
    monkeypatch.setenv("HYBRID_LAB_AZURE_TENANT_ID", "tenant-123")
    monkeypatch.setenv("HYBRID_LAB_AZURE_CLIENT_ID", "client-123")
    monkeypatch.setenv("HYBRID_LAB_AZURE_CLIENT_SECRET", "secret-123")
    monkeypatch.setenv("HYBRID_LAB_AZURE_LOCATION", "eastus")
    monkeypatch.setenv("HYBRID_LAB_AZURE_SSH_PUBLIC_KEY", "ssh-rsa AAAAtest")
    monkeypatch.setattr(
        "app.backends.azure.terraform_utils.plan",
        lambda env_dir, tfvars_path, env: "Plan: 1 to add, 0 to change, 0 to destroy.",
    )

    valid_payload["template"] = "ubuntu-22.04-azure"
    response = client.post("/environments", json=valid_payload)

    assert response.status_code == 201
    body = response.json()
    assert body["backend"] == "azure"
    assert body["backend_ref"].startswith("tf-plan-azure-"), body
    assert "simulated" not in body["detail"]


def test_vsphere_backend_activates_once_env_vars_are_set_after_import(
    client: TestClient, valid_payload: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_USER", "admin@vsphere.local")
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "hunter2")
    monkeypatch.setattr(
        "app.backends.vsphere.VSphereBackend._run",
        lambda self, script, args: json.dumps({"Id": "vm-real-123"}),
    )

    response = client.post("/environments", json=valid_payload)

    assert response.status_code == 201
    body = response.json()
    assert body["backend"] == "vsphere"
    assert body["backend_ref"] == "vm-real-123", body
    assert "simulated" not in body["detail"]
