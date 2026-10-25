"""Unit tests for the vSphere backend's own logic (env validation, command
construction, JSON parsing, error mapping) with subprocess.run mocked out.

These do not need pwsh or vcsim - that's what test_vsphere_backend_live.py is for.
"""

from __future__ import annotations

import json
import os
import subprocess
from datetime import UTC, datetime

import pytest

from app.backends.base import ProvisioningError
from app.backends.vsphere import VSphereBackend


@pytest.fixture()
def clean_vsphere_env(monkeypatch: pytest.MonkeyPatch) -> pytest.MonkeyPatch:
    for key in list(os.environ):
        if key.startswith("HYBRID_LAB_VSPHERE_"):
            monkeypatch.delenv(key, raising=False)
    return monkeypatch


def test_provision_requires_connection_env(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    backend = VSphereBackend()
    with pytest.raises(ProvisioningError, match="not configured"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-vsphere", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_deprovision_requires_connection_env(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    backend = VSphereBackend()
    with pytest.raises(ProvisioningError, match="not configured"):
        backend.deprovision(backend_ref="VirtualMachine-vm-1")


def test_pwsh_missing_raises(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    clean_vsphere_env.setattr("app.backends.vsphere.shutil.which", lambda name: None)

    backend = VSphereBackend()
    with pytest.raises(ProvisioningError, match="pwsh"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-vsphere", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_provision_reports_pwsh_failure(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    clean_vsphere_env.setattr("app.backends.vsphere.shutil.which", lambda name: "/usr/bin/pwsh")

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, returncode=1, stdout="", stderr="connection refused")

    clean_vsphere_env.setattr("app.backends.vsphere.subprocess.run", fake_run)

    backend = VSphereBackend()
    with pytest.raises(ProvisioningError, match="connection refused"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-vsphere", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_provision_rejects_unparseable_output(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    clean_vsphere_env.setattr("app.backends.vsphere.shutil.which", lambda name: "/usr/bin/pwsh")

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, returncode=0, stdout="not json", stderr="")

    clean_vsphere_env.setattr("app.backends.vsphere.subprocess.run", fake_run)

    backend = VSphereBackend()
    with pytest.raises(ProvisioningError, match="could not parse"):
        backend.provision(
            name="dev-1", template="ubuntu-22.04-vsphere", size="small", owner="a@example.com",
            expiry=datetime.now(UTC),
        )


def test_provision_builds_expected_command_and_parses_result(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PORTGROUP", "lab-net")
    clean_vsphere_env.setattr("app.backends.vsphere.shutil.which", lambda name: "/usr/bin/pwsh")

    captured: dict[str, list[str]] = {}

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        captured["args"] = args
        payload = {"Name": "dev-1", "Id": "VirtualMachine-vm-42", "PowerState": "PoweredOff"}
        return subprocess.CompletedProcess(args, returncode=0, stdout=json.dumps(payload) + "\n", stderr="")

    clean_vsphere_env.setattr("app.backends.vsphere.subprocess.run", fake_run)

    backend = VSphereBackend()
    expiry = datetime(2099, 1, 1, tzinfo=UTC)
    result = backend.provision(
        name="dev-1", template="ubuntu-22.04-vsphere", size="small", owner="a@example.com", expiry=expiry
    )

    assert result.backend_ref == "VirtualMachine-vm-42"
    assert "tpl-ubuntu-2204" in result.detail

    args = captured["args"]
    assert "Invoke-VSphereProvision.ps1" in args[args.index("-File") + 1]
    assert args[args.index("-Server") + 1] == "vcenter.test"
    assert args[args.index("-User") + 1] == "user"
    assert args[args.index("-TemplateName") + 1] == "tpl-ubuntu-2204"
    assert args[args.index("-Name") + 1] == "dev-1"
    assert args[args.index("-PortGroup") + 1] == "lab-net"
    assert args[args.index("-Owner") + 1] == "a@example.com"
    assert args[args.index("-Expiry") + 1] == expiry.isoformat()
    assert "-Password" not in args, "the password must never be passed as a CLI argument"


def test_provision_uses_template_override(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    clean_vsphere_env.setenv(
        "HYBRID_LAB_VSPHERE_TEMPLATE_OVERRIDES", json.dumps({"ubuntu-22.04-vsphere": "DC0_H0_VM0"})
    )
    clean_vsphere_env.setattr("app.backends.vsphere.shutil.which", lambda name: "/usr/bin/pwsh")

    captured: dict[str, list[str]] = {}

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        captured["args"] = args
        payload = {"Name": "dev-1", "Id": "VirtualMachine-vm-1", "PowerState": "PoweredOff"}
        return subprocess.CompletedProcess(args, returncode=0, stdout=json.dumps(payload), stderr="")

    clean_vsphere_env.setattr("app.backends.vsphere.subprocess.run", fake_run)

    backend = VSphereBackend()
    backend.provision(
        name="dev-1", template="ubuntu-22.04-vsphere", size="small", owner="a@example.com",
        expiry=datetime.now(UTC),
    )

    args = captured["args"]
    assert args[args.index("-TemplateName") + 1] == "DC0_H0_VM0"


def test_deprovision_builds_expected_command(clean_vsphere_env: pytest.MonkeyPatch) -> None:
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_SERVER", "vcenter.test")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    clean_vsphere_env.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    clean_vsphere_env.setattr("app.backends.vsphere.shutil.which", lambda name: "/usr/bin/pwsh")

    captured: dict[str, list[str]] = {}

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        captured["args"] = args
        return subprocess.CompletedProcess(args, returncode=0, stdout="", stderr="")

    clean_vsphere_env.setattr("app.backends.vsphere.subprocess.run", fake_run)

    backend = VSphereBackend()
    backend.deprovision(backend_ref="VirtualMachine-vm-42")

    args = captured["args"]
    assert "Invoke-VSphereDeprovision.ps1" in args[args.index("-File") + 1]
    assert args[args.index("-BackendRef") + 1] == "VirtualMachine-vm-42"
    assert "-Password" not in args
