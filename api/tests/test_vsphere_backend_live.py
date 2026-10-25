"""Live integration test: provisions and deprovisions a real VM on a real vcsim
container, through the exact pwsh + HybridLab module path the API uses in
production. Skipped automatically when docker or pwsh aren't available, since
that's the one thing this test genuinely needs that unit tests don't.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import time
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest

from app.backends.vsphere import VSphereBackend

pytestmark = pytest.mark.skipif(
    shutil.which("docker") is None or shutil.which("pwsh") is None,
    reason="requires docker and pwsh for a live vcsim integration test",
)

_CONTAINER_NAME = "hpl-pytest-vcsim"
_PORT = 18989


@pytest.fixture(scope="module")
def vcsim_port() -> Iterator[int]:
    subprocess.run(["docker", "rm", "-f", _CONTAINER_NAME], capture_output=True, check=False)
    subprocess.run(
        [
            "docker", "run", "-d", "--name", _CONTAINER_NAME,
            "-p", f"{_PORT}:8989", "vmware/vcsim", "-l", ":8989",
        ],
        capture_output=True,
        check=True,
    )
    try:
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            probe = subprocess.run(
                ["curl", "-sk", "-o", "/dev/null", "-w", "%{http_code}", f"https://127.0.0.1:{_PORT}/sdk"],
                capture_output=True,
                text=True,
                check=False,
            )
            if probe.stdout.strip() not in ("", "000"):
                break
            time.sleep(0.5)
        yield _PORT
    finally:
        subprocess.run(["docker", "rm", "-f", _CONTAINER_NAME], capture_output=True, check=False)


@pytest.fixture()
def vsphere_env(vcsim_port: int, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_SERVER", "127.0.0.1")
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_PORT", str(vcsim_port))
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_USER", "user")
    monkeypatch.setenv("HYBRID_LAB_VSPHERE_PASSWORD", "pass")
    # vcsim has no "tpl-ubuntu-2204" template VM; point the catalog's placeholder
    # name at a real vcsim fixture VM instead, the same way a real deployment
    # would override it for its own vCenter's actual template names.
    monkeypatch.setenv(
        "HYBRID_LAB_VSPHERE_TEMPLATE_OVERRIDES", json.dumps({"ubuntu-22.04-vsphere": "DC0_H0_VM0"})
    )


def test_provision_then_deprovision_against_vcsim(vsphere_env: None) -> None:
    backend = VSphereBackend()
    name = f"pytest-live-{int(time.time())}"
    expiry = datetime.now(UTC) + timedelta(hours=1)

    result = backend.provision(
        name=name, template="ubuntu-22.04-vsphere", size="small", owner="pytest@example.com", expiry=expiry
    )

    assert result.backend_ref.startswith("VirtualMachine-")
    assert "DC0_H0_VM0" in result.detail

    backend.deprovision(backend_ref=result.backend_ref)
