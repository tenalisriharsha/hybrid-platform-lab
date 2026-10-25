"""Shared plumbing for the Proxmox and Azure backends: both render a tfvars
file and run `terraform plan` against one of the terraform/environments/dev
folders, and never run `terraform apply` - see app/backends/proxmox.py and
app/backends/azure.py for the backend-specific pieces (required env vars,
catalog lookups, tfvars shape).
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from app.backends.base import ProvisioningError

_REPO_ROOT = Path(__file__).resolve().parents[3]
_TERRAFORM_ROOT = _REPO_ROOT / "terraform"

# `terraform init` downloads providers over the network the first time a given
# environment folder is used, which is much slower than a plan against an
# already-initialized one; `plan` itself is fast once providers are cached.
_INIT_TIMEOUT_SECONDS = 180
_PLAN_TIMEOUT_SECONDS = 60

_PLAN_SUMMARY_RE = re.compile(r"Plan: \d+ to add, \d+ to change, \d+ to destroy\.")


def environment_dir(backend: str, environment: str = "dev") -> Path:
    path = _TERRAFORM_ROOT / "environments" / environment / backend
    if not path.is_dir():
        raise ProvisioningError(f"no terraform environment folder at {path}")
    return path


def terraform_path() -> str:
    terraform = shutil.which("terraform")
    if terraform is None:
        raise ProvisioningError("terraform is not installed/available on PATH")
    return terraform


def render_tfvars_file(tfvars: dict[str, object]) -> Path:
    handle = tempfile.NamedTemporaryFile(
        mode="w", suffix=".tfvars.json", prefix="hybrid-lab-", delete=False
    )
    with handle:
        json.dump(tfvars, handle)
    return Path(handle.name)


def plan(env_dir: Path, tfvars_path: Path, env: dict[str, str]) -> str:
    """Runs `terraform init` (if needed) then `terraform plan` and returns the
    plan's stdout. Never runs `terraform apply`. Raises ProvisioningError on
    any non-zero exit, with the real terraform error attached.
    """
    terraform = terraform_path()

    if not (env_dir / ".terraform").is_dir():
        init = subprocess.run(
            [terraform, f"-chdir={env_dir}", "init", "-input=false", "-no-color"],
            capture_output=True,
            text=True,
            timeout=_INIT_TIMEOUT_SECONDS,
            env=env,
        )
        if init.returncode != 0:
            raise ProvisioningError(f"terraform init failed: {init.stderr.strip() or init.stdout.strip()}")

    completed = subprocess.run(
        [
            terraform,
            f"-chdir={env_dir}",
            "plan",
            "-input=false",
            "-no-color",
            f"-var-file={tfvars_path}",
        ],
        capture_output=True,
        text=True,
        timeout=_PLAN_TIMEOUT_SECONDS,
        env=env,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise ProvisioningError(f"terraform plan failed: {detail}")
    return completed.stdout


def plan_summary(stdout: str) -> str:
    match = _PLAN_SUMMARY_RE.search(stdout)
    if match:
        return match.group(0)
    if "No changes." in stdout:
        return "No changes."
    return "terraform plan succeeded"
