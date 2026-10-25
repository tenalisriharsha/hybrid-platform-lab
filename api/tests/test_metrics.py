from __future__ import annotations

from fastapi.testclient import TestClient


def test_metrics_endpoint_exposes_request_counter(client: TestClient) -> None:
    client.get("/healthz")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text
    assert "http_request_duration_seconds" in response.text


def test_metrics_tracks_environment_gauge_after_create(client: TestClient, valid_payload: dict) -> None:
    client.post("/environments", json=valid_payload)
    response = client.get("/metrics")
    assert 'environments_total{backend="vsphere",status="ready"} 1.0' in response.text


def test_metrics_gauge_updates_after_delete(client: TestClient, valid_payload: dict) -> None:
    created = client.post("/environments", json=valid_payload).json()
    client.delete(f"/environments/{created['id']}")

    response = client.get("/metrics")
    assert 'environments_total{backend="vsphere",status="deleted"} 1.0' in response.text
    assert 'environments_total{backend="vsphere",status="ready"} 1.0' not in response.text


def test_healthz(client: TestClient) -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
