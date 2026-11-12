from __future__ import annotations

import concurrent.futures as cf
from collections import Counter

from fastapi.testclient import TestClient

from app.main import create_app

MAX_ATTEMPTS = 5
WORKERS = 60
REQUESTS_PER_ATTEMPT = 200


def _post_many(client: TestClient) -> Counter:
    def post(i: int) -> int:
        payload = {
            "name": f"load-{i}",
            "template": "ubuntu-22.04-vsphere",
            "size": "small",
            "owner": "alice@example.com",
        }
        response = client.post("/environments", json=payload)
        return response.status_code

    with cf.ThreadPoolExecutor(max_workers=WORKERS) as executor:
        results = list(executor.map(post, range(REQUESTS_PER_ATTEMPT)))
    return Counter(results)


def test_concurrent_creates_never_return_raw_500() -> None:
    """Issue #18: racing reads/writes on the shared sqlite connection could
    make `list()` observe a row mid-insert and crash with an unhandled
    pydantic ValidationError, surfaced to the client as a bare 500. Retries
    a fresh app/store each attempt since the race window is small; a fixed
    store should never produce a 500 across any attempt.
    """
    for _ in range(MAX_ATTEMPTS):
        app = create_app(db_path=":memory:")
        client = TestClient(app, raise_server_exceptions=False)

        counts = _post_many(client)

        assert counts[500] == 0, f"got a raw 500 among concurrent creates: {counts}"
        assert counts[201] == REQUESTS_PER_ATTEMPT
