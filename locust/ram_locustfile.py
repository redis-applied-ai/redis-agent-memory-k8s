from __future__ import annotations

import os
import random
import time
from uuid import uuid4

from locust import FastHttpUser, between, task


STORE_ID = os.environ["RAM_STORE_ID"]
AUTH_TOKEN = os.getenv("RAM_AUTH_TOKEN", "")
INCLUDE_LTM_SEARCH = os.getenv("RAM_INCLUDE_LTM_SEARCH", "true").lower() == "true"

PROMPTS = [
    "I prefer concise status summaries about Redis Agent Memory.",
    "Remember that the RAM harness is running on Kubernetes first.",
    "The deployment uses direct OpenAI calls for embeddings and promotion.",
    "Search should find long-term memory about Redis Enterprise.",
    "The agent should remember deployment preferences for production.",
]

SEARCH_TERMS = [
    "Redis Agent Memory Kubernetes",
    "OpenAI embeddings proof of concept",
    "Redis Enterprise vector search",
    "production Kubernetes deployment",
    "session memory and long-term memory",
]


def now_ms() -> int:
    return int(time.time() * 1000)


def short_id(prefix: str) -> str:
    return f"{prefix}-{uuid4().hex[:24]}"


class RamSessionUser(FastHttpUser):
    wait_time = between(0.2, 1.5)

    def on_start(self) -> None:
        self.session_id = short_id("s")
        self.actor_id = short_id("u")
        if AUTH_TOKEN:
            self.client.headers.update({"Authorization": f"Bearer {AUTH_TOKEN}"})
        self._write_event("/session-memory/events [setup]")

    def _write_event(self, name: str = "/session-memory/events") -> None:
        payload = {
            "sessionId": self.session_id,
            "actorId": self.actor_id,
            "role": "USER",
            "content": [{"text": random.choice(PROMPTS)}],
            "createdAt": now_ms(),
            "metadata": {"source": "locust", "profile": "ram"},
        }
        with self.client.post(
            f"/v1/stores/{STORE_ID}/session-memory/events",
            json=payload,
            name=name,
            catch_response=True,
        ) as response:
            if not 200 <= response.status_code < 300:
                response.failure(f"expected 2xx, got {response.status_code}: {response.text[:200]}")

    @task(int(os.getenv("RAM_WRITE_WEIGHT", "6")))
    def write_session_event(self) -> None:
        self._write_event()

    @task(int(os.getenv("RAM_READ_WEIGHT", "3")))
    def get_session_memory(self) -> None:
        with self.client.get(
            f"/v1/stores/{STORE_ID}/session-memory/{self.session_id}",
            name="/session-memory/{sessionId}",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"expected 200, got {response.status_code}: {response.text[:200]}")

    @task(int(os.getenv("RAM_SEARCH_WEIGHT", "1")))
    def search_long_term_memory(self) -> None:
        if not INCLUDE_LTM_SEARCH:
            return
        payload = {
            "text": random.choice(SEARCH_TERMS),
            "filter": {
                "namespace": {"eq": "ram-load"},
            },
            "filterOp": "all",
            "limit": 10,
        }
        with self.client.post(
            f"/v1/stores/{STORE_ID}/long-term-memory/search",
            json=payload,
            name="/long-term-memory/search",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"expected 200, got {response.status_code}: {response.text[:200]}")
