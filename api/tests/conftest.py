from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture()
def client() -> TestClient:
    app = create_app(db_path=":memory:")
    return TestClient(app)


@pytest.fixture()
def valid_payload() -> dict:
    return {
        "name": "dev-box-1",
        "template": "ubuntu-22.04-vsphere",
        "size": "small",
        "owner": "alice@example.com",
    }
