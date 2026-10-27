from __future__ import annotations

import os
import time

from fastapi import FastAPI, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from app.metrics import Metrics
from app.routers.environments import router as environments_router
from app.store import EnvironmentStore


def create_app(db_path: str | None = None) -> FastAPI:
    app = FastAPI(
        title="Hybrid Platform Lab API",
        description=(
            "Self-service VM environments across vSphere, Proxmox VE and Azure. "
            "Validates requests against approved templates and sizes; actual "
            "provisioning is delegated to a per-backend module."
        ),
        version="0.1.0",
    )
    app.state.store = EnvironmentStore(db_path or os.environ.get("HYBRID_LAB_DB", ":memory:"))
    app.state.metrics = Metrics()
    app.include_router(environments_router)

    @app.middleware("http")
    async def record_metrics(request: Request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        duration = time.perf_counter() - start
        route = request.scope.get("route")
        path_label = route.path if route is not None else "unmatched"
        request.app.state.metrics.observe_request(
            method=request.method,
            path=path_label,
            status_code=response.status_code,
            duration_seconds=duration,
        )
        return response

    @app.get("/healthz", tags=["health"])
    def healthz() -> dict:
        return {"status": "ok"}

    @app.get("/metrics", tags=["health"])
    def metrics(http_request: Request) -> Response:
        registry = http_request.app.state.metrics.registry
        return Response(content=generate_latest(registry), media_type=CONTENT_TYPE_LATEST)

    return app


app = create_app()
