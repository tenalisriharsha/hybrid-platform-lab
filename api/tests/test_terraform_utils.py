"""Unit tests for the shared Terraform plumbing (app/backends/terraform_utils.py)
used by both the Proxmox and Azure backends.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from app.backends import terraform_utils
from app.backends.base import ProvisioningError


def test_environment_dir_resolves_known_backend() -> None:
    path = terraform_utils.environment_dir("proxmox")
    assert path.name == "proxmox"
    assert (path / "main.tf").is_file()


def test_environment_dir_rejects_unknown_backend() -> None:
    with pytest.raises(ProvisioningError, match="no terraform environment folder"):
        terraform_utils.environment_dir("not-a-real-backend")


def test_terraform_path_raises_when_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.backends.terraform_utils.shutil.which", lambda name: None)
    with pytest.raises(ProvisioningError, match="terraform is not installed"):
        terraform_utils.terraform_path()


def test_render_tfvars_file_writes_valid_json() -> None:
    path = terraform_utils.render_tfvars_file({"name": "dev-1", "cpu_cores": 2})
    try:
        assert json.loads(path.read_text()) == {"name": "dev-1", "cpu_cores": 2}
    finally:
        path.unlink()


_PLAN_LINE = "Plan: 1 to add, 0 to change, 0 to destroy."


@pytest.mark.parametrize(
    ("stdout", "expected"),
    [
        (f"blah\n{_PLAN_LINE}\nblah", _PLAN_LINE),
        ("No changes. Your infrastructure matches the configuration.", "No changes."),
        ("some unrelated output", "terraform plan succeeded"),
    ],
)
def test_plan_summary(stdout: str, expected: str) -> None:
    assert terraform_utils.plan_summary(stdout) == expected


def test_plan_raises_when_init_fails(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr("app.backends.terraform_utils.terraform_path", lambda: "/usr/bin/terraform")

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        assert args[2] == "init"
        return subprocess.CompletedProcess(args, returncode=1, stdout="", stderr="no network")

    monkeypatch.setattr("app.backends.terraform_utils.subprocess.run", fake_run)

    env_dir = tmp_path / "env"
    env_dir.mkdir()
    tfvars_path = terraform_utils.render_tfvars_file({})
    try:
        with pytest.raises(ProvisioningError, match="terraform init failed"):
            terraform_utils.plan(env_dir, tfvars_path, env={})
    finally:
        tfvars_path.unlink()


def test_plan_raises_when_plan_fails(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr("app.backends.terraform_utils.terraform_path", lambda: "/usr/bin/terraform")

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        assert args[2] == "plan"
        return subprocess.CompletedProcess(args, returncode=1, stdout="", stderr="connection refused")

    monkeypatch.setattr("app.backends.terraform_utils.subprocess.run", fake_run)

    # already-initialized env dir, so plan() skips straight to `terraform plan`
    env_dir = tmp_path / "env"
    (env_dir / ".terraform").mkdir(parents=True)
    tfvars_path = terraform_utils.render_tfvars_file({})
    try:
        with pytest.raises(ProvisioningError, match="connection refused"):
            terraform_utils.plan(env_dir, tfvars_path, env={})
    finally:
        tfvars_path.unlink()


def test_plan_returns_stdout_on_success(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr("app.backends.terraform_utils.terraform_path", lambda: "/usr/bin/terraform")

    def fake_run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, returncode=0, stdout=_PLAN_LINE, stderr="")

    monkeypatch.setattr("app.backends.terraform_utils.subprocess.run", fake_run)

    env_dir = tmp_path / "env"
    (env_dir / ".terraform").mkdir(parents=True)
    tfvars_path = terraform_utils.render_tfvars_file({})
    try:
        stdout = terraform_utils.plan(env_dir, tfvars_path, env={})
        assert "1 to add" in stdout
    finally:
        tfvars_path.unlink()
