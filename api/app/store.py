from __future__ import annotations

import sqlite3
import threading

from app.models import Environment, EnvironmentStatus


class EnvironmentStore:
    """SQLite-backed store for environments.

    The full record is kept as JSON; owner/backend/status are duplicated
    into columns so GET /environments can filter without deserializing
    every row.
    """

    def __init__(self, db_path: str = ":memory:") -> None:
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS environments (
                id TEXT PRIMARY KEY,
                owner TEXT NOT NULL,
                backend TEXT NOT NULL,
                status TEXT NOT NULL,
                payload TEXT NOT NULL
            )
            """
        )
        self._conn.commit()

    def create(self, environment: Environment) -> Environment:
        with self._lock:
            self._conn.execute(
                "INSERT INTO environments (id, owner, backend, status, payload) VALUES (?, ?, ?, ?, ?)",
                (
                    environment.id,
                    environment.owner,
                    environment.backend,
                    environment.status.value,
                    environment.model_dump_json(),
                ),
            )
            self._conn.commit()
        return environment

    def get(self, environment_id: str) -> Environment | None:
        row = self._conn.execute(
            "SELECT payload FROM environments WHERE id = ?", (environment_id,)
        ).fetchone()
        if row is None:
            return None
        return Environment.model_validate_json(row[0])

    def list(
        self,
        *,
        owner: str | None = None,
        backend: str | None = None,
        status: str | None = None,
        include_deleted: bool = False,
    ) -> list[Environment]:
        query = "SELECT payload FROM environments WHERE 1=1"
        params: list[str] = []
        if owner is not None:
            query += " AND owner = ?"
            params.append(owner)
        if backend is not None:
            query += " AND backend = ?"
            params.append(backend)
        if status is not None:
            query += " AND status = ?"
            params.append(status)
        elif not include_deleted:
            query += " AND status != ?"
            params.append(EnvironmentStatus.DELETED.value)
        rows = self._conn.execute(query, params).fetchall()
        return [Environment.model_validate_json(row[0]) for row in rows]

    def update(self, environment: Environment) -> Environment:
        with self._lock:
            self._conn.execute(
                "UPDATE environments SET owner = ?, backend = ?, status = ?, payload = ? WHERE id = ?",
                (
                    environment.owner,
                    environment.backend,
                    environment.status.value,
                    environment.model_dump_json(),
                    environment.id,
                ),
            )
            self._conn.commit()
        return environment

    def close(self) -> None:
        self._conn.close()
