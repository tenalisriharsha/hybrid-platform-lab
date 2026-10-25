from __future__ import annotations

from prometheus_client import CollectorRegistry, Counter, Gauge, Histogram

from app.store import EnvironmentStore


class Metrics:
    """Prometheus collectors, scoped to one registry per app instance.

    A per-app registry (rather than prometheus_client's global default) lets
    tests spin up several app instances in the same process without hitting
    "duplicate metric" registration errors.
    """

    def __init__(self) -> None:
        self.registry = CollectorRegistry()
        self.http_requests_total = Counter(
            "http_requests_total",
            "Total HTTP requests handled by the API.",
            ["method", "path", "status_code"],
            registry=self.registry,
        )
        self.http_request_duration_seconds = Histogram(
            "http_request_duration_seconds",
            "HTTP request duration in seconds.",
            ["method", "path"],
            registry=self.registry,
        )
        self.environments_gauge = Gauge(
            "environments_total",
            "Current environments by backend and status.",
            ["backend", "status"],
            registry=self.registry,
        )

    def observe_request(self, *, method: str, path: str, status_code: int, duration_seconds: float) -> None:
        self.http_requests_total.labels(method=method, path=path, status_code=str(status_code)).inc()
        self.http_request_duration_seconds.labels(method=method, path=path).observe(duration_seconds)

    def refresh_environment_gauge(self, store: EnvironmentStore) -> None:
        self.environments_gauge.clear()
        for environment in store.list(include_deleted=True):
            self.environments_gauge.labels(backend=environment.backend, status=environment.status.value).inc()
