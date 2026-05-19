# Load Testing

One Locust user maps to one RAM session. Each user keeps one `sessionId`, writes session events, reads that session, and can optionally search long-term memory.

For the working-memory profile, write request and response sizes are effectively fixed. Session reads fetch the full session, so the read response grows as each Locust user's session accumulates events.

In RAM, the working-memory path is the session-memory API:

```text
POST /v1/stores/{storeId}/session-memory/events
GET  /v1/stores/{storeId}/session-memory/{sessionId}
```

## Setup

Use the root [README](../README.md) as the setup source of truth. After `make up` succeeds, keep the local port-forward open:

```sh
make port-forward
```

That single target forwards RAM, Prometheus, and Grafana. Use `./scripts/port-forward.sh --ram-only` or `./scripts/port-forward.sh --monitoring-only` only when you intentionally want a narrower local tunnel.

Install Locust:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r locust/requirements.txt
```

Default Locust UI settings live in `.env` or `env/ram.kind.env.example`:

```sh
LOCUST_WEB_HOST=127.0.0.1
LOCUST_WEB_PORT=8089
```

Reset data before a clean run:

```sh
make reset-data
```

Then start or restart the local forwards:

```sh
make port-forward
```

All load targets start the Locust UI. Choose user count and spawn rate in the UI.

```sh
make load-working-memory
```

If you interrupt Locust while requests are in flight, `kubectl port-forward` can see the client side close first and report a broken pipe. That is a local forwarding artifact, not an infra failure.

## Profiles

`make load-working-memory`

Scales the RAM worker to zero and starts the Locust web UI for session write/read traffic only. Session writes and reads are weighted 50/50. This is the clean RAM API plus Redis Enterprise baseline because it avoids long-term memory search and worker promotion calls to the model provider.

`make load-search`

Keeps the worker at zero and adds long-term memory search traffic. Seed memories first:

```sh
make seed-ltm
make load-search
```

`make load-promotion`

Scales the worker back on and runs write/read traffic while background promotion jobs are processed.

The working-memory and search profiles leave the worker scaled to zero. A large write-heavy run can leave promotion jobs queued in Redis Streams; reset the stack or intentionally run the promotion profile before comparing worker behavior.

## Reset Test Data

`make reset-data`

Flushes the `ram-content` and `ram-jobs` REDBs, then restarts RAM server and worker deployments. Use it before a new load run when you want a clean RAM dataset without rebuilding the kind cluster.

The monitoring stack is intentionally left alone. Prometheus and Grafana remain running, ServiceMonitors and dashboards stay installed, and retained time series are preserved. Expect RAM process metrics and counters to reset when the RAM deployments restart.

If `make port-forward` was already running, stop and restart it after `make reset-data` because the RAM pod is restarted.

## Results

Use the Locust UI to watch request rate, latency, failures, and endpoint-level stats. Export reports from the UI when you need to keep results.

Use Grafana at `http://127.0.0.1:3000` for durable time-series during the same run. The bundled RAM dashboard shows RAM HTTP rate and average handler latency, Redis client command rate and average duration, Redis client pool waits/timeouts, and scrape health. Prometheus is available at `http://127.0.0.1:9090` for direct queries such as `up`, `gin_request_duration_seconds_count`, `db_client_connections_use_time_milliseconds_count`, and Redis Enterprise v2 metrics such as `endpoint_client_connections`.

Locust and Grafana answer different questions:

- Locust UI: simulated-user request behavior, endpoint latency, request rate, and failures.
- Prometheus/Grafana: retained time-series for RAM, Redis Enterprise, Kubernetes pods/nodes, and scrape target health.

Locust does not scrape RAM `/metrics` directly. That keeps Locust focused on generated user traffic, while Prometheus owns scrape cadence, retention, target health, and dashboard queries.

The raw RAM metrics remain available through Prometheus. They are also reachable through the RAM port-forward when you need a direct spot check:

```sh
curl http://127.0.0.1:9000/metrics
```

## Prometheus And Grafana

`make up` installs `kube-prometheus-stack` by default. Prometheus scrapes:

- RAM at service `redis-agent-memory`, port `http`, path `/metrics`.
- Redis Enterprise at service `rec-prom`, port `prometheus`, path `/v2` over HTTPS with self-signed TLS allowed for this kind harness.
- Kubernetes components provided by `kube-prometheus-stack`, including kube-state-metrics and node exporter.

Check the monitoring layer:

```sh
make monitoring-status
kubectl -n monitoring get pods,svc
kubectl -n ram get servicemonitor
kubectl -n monitoring get prometheus,servicemonitor
kubectl -n monitoring get deploy ram-observability-grafana
```

The Grafana Prometheus datasource is provisioned by the chart. The RAM dashboard is loaded from `k8s/monitoring/dashboards/`. For deeper Redis Enterprise views, import Redis's official v2 Grafana dashboards from the [Redis Enterprise Prometheus/Grafana documentation](https://redis.io/docs/latest/integrate/prometheus-with-redis-enterprise/).

## Watch During A Test

```sh
make status
make monitoring-status
make logs
kubectl -n ram get pods
```

If a metrics server is installed:

```sh
kubectl -n ram top pods
```

## What To Capture For Customer Runs

- RAM request rate, latency, and error rate
- Redis Enterprise node CPU, memory, proxy latency, shard placement, vector index memory, and evictions
- Redis Streams length, pending count, retry count, and oldest pending age
- Model provider request rate, latency, throttling, and spend
- Gateway latency, quota rejects, auth rejects, and 5xx responses
