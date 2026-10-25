from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request, status

from app.backends import ProvisioningError, get_backend
from app.catalog import SIZES, TEMPLATES
from app.models import Environment, EnvironmentCreateRequest, EnvironmentStatus

router = APIRouter(tags=["environments"])


@router.get("/catalog")
def get_catalog() -> dict:
    return {"templates": TEMPLATES, "sizes": SIZES}


@router.post("/environments", status_code=status.HTTP_201_CREATED)
def create_environment(request: EnvironmentCreateRequest, http_request: Request) -> Environment:
    store = http_request.app.state.store
    metrics = http_request.app.state.metrics

    environment = Environment.from_request(request)
    backend = get_backend(environment.backend)
    try:
        result = backend.provision(
            name=environment.name,
            template=environment.template,
            size=environment.size,
            owner=environment.owner,
            expiry=environment.expiry,
        )
    except ProvisioningError as exc:
        environment.status = EnvironmentStatus.FAILED
        environment.detail = str(exc)
        store.create(environment)
        metrics.refresh_environment_gauge(store)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    environment.backend_ref = result.backend_ref
    environment.detail = result.detail
    store.create(environment)
    metrics.refresh_environment_gauge(store)
    return environment


@router.get("/environments")
def list_environments(
    http_request: Request,
    owner: str | None = None,
    backend: str | None = None,
    status_filter: str | None = None,
    include_deleted: bool = False,
) -> list[Environment]:
    store = http_request.app.state.store
    return store.list(owner=owner, backend=backend, status=status_filter, include_deleted=include_deleted)


@router.get("/environments/{environment_id}")
def get_environment(environment_id: str, http_request: Request) -> Environment:
    store = http_request.app.state.store
    environment = store.get(environment_id)
    if environment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="environment not found")
    return environment


@router.delete("/environments/{environment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_environment(environment_id: str, http_request: Request) -> None:
    store = http_request.app.state.store
    metrics = http_request.app.state.metrics

    environment = store.get(environment_id)
    if environment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="environment not found")
    if environment.status == EnvironmentStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="environment already deleted")

    backend = get_backend(environment.backend)
    if environment.backend_ref is not None:
        try:
            backend.deprovision(backend_ref=environment.backend_ref)
        except ProvisioningError as exc:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    environment.status = EnvironmentStatus.DELETED
    store.update(environment)
    metrics.refresh_environment_gauge(store)
