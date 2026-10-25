from __future__ import annotations

from fastapi.testclient import TestClient


def test_create_environment_returns_201_with_spec(client: TestClient, valid_payload: dict) -> None:
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "dev-box-1"
    assert body["backend"] == "vsphere"
    assert body["status"] == "ready"
    assert body["spec"] == {"cpu": 2, "memory_gb": 4, "disk_gb": 40}
    assert body["backend_ref"].startswith("sim-vsphere-")


def test_create_environment_derives_backend_from_template(client: TestClient, valid_payload: dict) -> None:
    valid_payload["template"] = "ubuntu-22.04-azure"
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 201
    assert response.json()["backend"] == "azure"


def test_expiry_is_after_created_at(client: TestClient, valid_payload: dict) -> None:
    valid_payload["ttl_hours"] = 5
    response = client.post("/environments", json=valid_payload)
    body = response.json()
    assert body["expiry"] > body["created_at"]


def test_reject_unknown_template(client: TestClient, valid_payload: dict) -> None:
    valid_payload["template"] = "does-not-exist"
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 422


def test_reject_unknown_size(client: TestClient, valid_payload: dict) -> None:
    valid_payload["size"] = "xl"
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 422


def test_reject_invalid_owner(client: TestClient, valid_payload: dict) -> None:
    valid_payload["owner"] = "not-an-email"
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 422


def test_reject_invalid_name(client: TestClient, valid_payload: dict) -> None:
    valid_payload["name"] = "Invalid Name!"
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 422


def test_reject_ttl_over_max(client: TestClient, valid_payload: dict) -> None:
    valid_payload["ttl_hours"] = 24 * 30
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 422


def test_reject_ttl_zero_or_negative(client: TestClient, valid_payload: dict) -> None:
    valid_payload["ttl_hours"] = 0
    response = client.post("/environments", json=valid_payload)
    assert response.status_code == 422


def test_get_environment_by_id(client: TestClient, valid_payload: dict) -> None:
    created = client.post("/environments", json=valid_payload).json()
    response = client.get(f"/environments/{created['id']}")
    assert response.status_code == 200
    assert response.json()["id"] == created["id"]


def test_get_missing_environment_returns_404(client: TestClient) -> None:
    response = client.get("/environments/does-not-exist")
    assert response.status_code == 404


def test_list_environments(client: TestClient, valid_payload: dict) -> None:
    client.post("/environments", json=valid_payload)
    second = dict(valid_payload, name="dev-box-2", owner="bob@example.com")
    client.post("/environments", json=second)

    response = client.get("/environments")
    assert response.status_code == 200
    names = {env["name"] for env in response.json()}
    assert names == {"dev-box-1", "dev-box-2"}


def test_list_environments_filters_by_owner(client: TestClient, valid_payload: dict) -> None:
    client.post("/environments", json=valid_payload)
    second = dict(valid_payload, name="dev-box-2", owner="bob@example.com")
    client.post("/environments", json=second)

    response = client.get("/environments", params={"owner": "bob@example.com"})
    assert [env["name"] for env in response.json()] == ["dev-box-2"]


def test_list_environments_filters_by_backend(client: TestClient, valid_payload: dict) -> None:
    client.post("/environments", json=valid_payload)
    azure_env = dict(valid_payload, name="dev-box-3", template="ubuntu-22.04-azure")
    client.post("/environments", json=azure_env)

    response = client.get("/environments", params={"backend": "azure"})
    body = response.json()
    assert len(body) == 1
    assert body[0]["backend"] == "azure"


def test_delete_environment_marks_deleted_and_excludes_from_default_list(
    client: TestClient, valid_payload: dict
) -> None:
    created = client.post("/environments", json=valid_payload).json()

    delete_response = client.delete(f"/environments/{created['id']}")
    assert delete_response.status_code == 204

    get_response = client.get(f"/environments/{created['id']}")
    assert get_response.json()["status"] == "deleted"

    list_response = client.get("/environments")
    assert list_response.json() == []

    list_with_deleted = client.get("/environments", params={"include_deleted": True})
    assert len(list_with_deleted.json()) == 1


def test_delete_missing_environment_returns_404(client: TestClient) -> None:
    response = client.delete("/environments/does-not-exist")
    assert response.status_code == 404


def test_delete_already_deleted_environment_returns_409(client: TestClient, valid_payload: dict) -> None:
    created = client.post("/environments", json=valid_payload).json()
    client.delete(f"/environments/{created['id']}")

    response = client.delete(f"/environments/{created['id']}")
    assert response.status_code == 409


def test_get_catalog(client: TestClient) -> None:
    response = client.get("/catalog")
    assert response.status_code == 200
    body = response.json()
    assert "ubuntu-22.04-vsphere" in body["templates"]
    assert "small" in body["sizes"]
