"""Azure OpenAI workload-identity canary.

Fires a small embedding request on a fixed interval using DefaultAzureCredential.
Designed to run in a pod with the Azure Workload Identity webhook injected
(`azure.workload.identity/use: "true"` label + annotated ServiceAccount).
"""

from __future__ import annotations

import logging
import os
import sys
import time

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("aoai-canary")


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        log.error("required env var %s is not set", name)
        sys.exit(2)
    return value


def main() -> None:
    endpoint = require_env("AZURE_OPENAI_ENDPOINT")
    deployment = require_env("AZURE_OPENAI_EMBEDDING_DEPLOYMENT")
    api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-06-01")
    interval = int(os.environ.get("INTERVAL_SECONDS", "10"))
    text = os.environ.get("EMBEDDING_INPUT", "hello from the aoai canary")

    log.info(
        "starting aoai canary endpoint=%s deployment=%s api_version=%s interval=%ds",
        endpoint, deployment, api_version, interval,
    )

    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential, "https://cognitiveservices.azure.com/.default"
    )
    client = AzureOpenAI(
        azure_endpoint=endpoint,
        azure_ad_token_provider=token_provider,
        api_version=api_version,
    )

    iteration = 0
    while True:
        iteration += 1
        started = time.monotonic()
        try:
            response = client.embeddings.create(model=deployment, input=text)
            elapsed_ms = int((time.monotonic() - started) * 1000)
            dim = len(response.data[0].embedding) if response.data else 0
            tokens = getattr(response.usage, "prompt_tokens", "?")
            log.info(
                "iter=%d ok dim=%d tokens=%s elapsed_ms=%d",
                iteration, dim, tokens, elapsed_ms,
            )
        except Exception as exc:
            elapsed_ms = int((time.monotonic() - started) * 1000)
            log.error(
                "iter=%d FAILED elapsed_ms=%d error=%s",
                iteration, elapsed_ms, exc,
            )
        time.sleep(interval)


if __name__ == "__main__":
    main()
