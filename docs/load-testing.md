# Load Testing

One Locust user maps to one RAM session. Each user keeps one `sessionId`, writes session events, reads that session, and can optionally search long-term memory.

## Setup

Use the root [README](../README.md) as the setup source of truth. After `make up` succeeds, keep a port-forward open:

```sh
make port-forward
```

Install Locust:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r locust/requirements.txt
```

Default local load settings live in `.env` or `env/ram.local.env.example`:

```sh
LOCUST_USERS=100
LOCUST_SPAWN_RATE=10
LOCUST_DURATION=10m
```

Override them per run:

```sh
LOCUST_USERS=500 LOCUST_SPAWN_RATE=25 LOCUST_DURATION=15m make load-session
```

## Profiles

`make load-session`

Scales the RAM worker to zero and runs session write/read traffic only. This is the clean RAM API plus Redis Enterprise baseline because it avoids worker promotion calls to the model provider.

`make load-search`

Keeps the worker at zero and adds long-term memory search traffic. Seed memories first:

```sh
make seed-ltm
make load-search
```

`make load-promotion`

Scales the worker back on and runs write/read traffic while background promotion jobs are processed.

## Results

`locust/run-local.sh` writes CSV and HTML reports under `results/` with the profile, user count, and UTC timestamp in the filename.

## Watch During A Test

```sh
make status
make logs
kubectl -n ram-local get pods
```

If a metrics server is installed:

```sh
kubectl -n ram-local top pods
```

## What To Capture For Customer Runs

- RAM request rate, latency, and error rate
- Redis Enterprise node CPU, memory, proxy latency, shard placement, vector index memory, and evictions
- Redis Streams length, pending count, retry count, and oldest pending age
- Model provider request rate, latency, throttling, and spend
- Gateway latency, quota rejects, auth rejects, and 5xx responses
