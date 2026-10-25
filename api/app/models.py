from __future__ import annotations

from datetime import UTC, datetime, timedelta
from enum import StrEnum
from uuid import uuid4

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.catalog import DEFAULT_TTL_HOURS, MAX_TTL_HOURS, SIZES, TEMPLATES, backend_for_template


class EnvironmentStatus(StrEnum):
    READY = "ready"
    FAILED = "failed"
    DELETED = "deleted"


class EnvironmentCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=63, pattern=r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")
    template: str
    size: str
    owner: EmailStr
    ttl_hours: int = Field(default=DEFAULT_TTL_HOURS, gt=0, le=MAX_TTL_HOURS)

    @field_validator("template")
    @classmethod
    def template_must_be_approved(cls, value: str) -> str:
        if value not in TEMPLATES:
            raise ValueError(f"unknown template {value!r}; approved templates: {sorted(TEMPLATES)}")
        return value

    @field_validator("size")
    @classmethod
    def size_must_be_approved(cls, value: str) -> str:
        if value not in SIZES:
            raise ValueError(f"unknown size {value!r}; approved sizes: {sorted(SIZES)}")
        return value


class Environment(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    name: str
    template: str
    backend: str
    size: str
    spec: dict[str, int]
    owner: EmailStr
    status: EnvironmentStatus
    created_at: datetime
    expiry: datetime
    backend_ref: str | None = None
    detail: str | None = None

    @model_validator(mode="after")
    def expiry_after_creation(self) -> Environment:
        if self.expiry <= self.created_at:
            raise ValueError("expiry must be after created_at")
        return self

    @classmethod
    def from_request(cls, request: EnvironmentCreateRequest) -> Environment:
        created_at = datetime.now(UTC)
        return cls(
            name=request.name,
            template=request.template,
            backend=backend_for_template(request.template),
            size=request.size,
            spec=SIZES[request.size],
            owner=request.owner,
            status=EnvironmentStatus.READY,
            created_at=created_at,
            expiry=created_at + timedelta(hours=request.ttl_hours),
        )
