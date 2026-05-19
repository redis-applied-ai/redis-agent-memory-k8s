# Redis Agent Memory Enterprise Harness

This is the source of truth for running this stack with kind.

## What This Is

This harness runs Redis Agent Memory (RAM) on kind using Redis Enterprise for Kubernetes. It is meant to validate the same deployment shape we would later use in AKS: Redis Enterprise operator, Redis Enterprise cluster, Redis Enterprise databases, generated database connection secrets, and a RAM Helm release.

Use it to prove RAM session memory, long-term memory, vector search, Redis Streams promotion jobs, OpenAI-backed embeddings/promotion, Prometheus/Grafana observability, and basic load profiles before moving the pattern into a customer or cloud environment.

This is not a Redis Stack shortcut and does not run Redis Enterprise in standalone Docker. Redis is provisioned only through Kubernetes resources.

## What Runs

- A 4-node `kind` cluster: 1 control-plane and 3 workers.
- Redis Enterprise operator from `redis/redis-enterprise-operator`.
- RedisEnterpriseCluster `rec`.
- RedisEnterpriseDatabase `ram-content` for session memory, long-term memory, JSON, Search, and vectors.
- RedisEnterpriseDatabase `ram-jobs` for Redis Streams promotion jobs.
- RAM API server and RAM worker from the RAM Helm chart.
- Prometheus Operator, Prometheus, Grafana, kube-state-metrics, and node exporter from `kube-prometheus-stack`.
- ServiceMonitors for RAM `/metrics` and Redis Enterprise `rec-prom:8070/v2`.
- OpenAI calls from RAM for embeddings and memory promotion.
- Locust load tests.

## System Outline

```text
Client, smoke test, or Locust
  -> RAM API server
    -> ram-content REDB for session memory, long-term memory, JSON, Search, and vectors
    -> ram-jobs REDB for Redis Streams promotion jobs
      -> RAM worker
        -> RAM API callback
        -> OpenAI embeddings/chat APIs
        -> ram-content REDB long-term memory records

Prometheus
  -> RAM API server /metrics
  -> Redis Enterprise rec-prom /v2
  -> Kubernetes pods, services, nodes, and scrape health
    -> Grafana dashboards
```

The RAM API server handles request/response paths such as writing session events, reading working memory, creating long-term memories, and searching long-term memory. The RAM worker handles asynchronous promotion jobs from Redis Streams: it reads queued work, calls the model provider, creates embeddings, and stores extracted memories.

The stack is deliberately split into two phases:

- [scripts/kind-up.sh](./scripts/kind-up.sh): create or reuse the kind cluster.
- [scripts/deploy-stack.sh](./scripts/deploy-stack.sh): deploy Redis Enterprise, render RAM config, create RAM Secrets, install RAM, and install Prometheus/Grafana monitoring.

`make up` runs both phases. `make deploy-stack` can be used later against any configured Kubernetes context, which keeps the deployment flow easier to translate to AKS.

No Redis Enterprise license file is required for this harness. Redis Enterprise starts with a trial license; `make status` shows the license state and expiration date.

## Prerequisites

- Docker Desktop with enough resources for Redis Enterprise plus RAM. Start with at least 8 CPUs and 12-16 GB memory if Docker Desktop allows it.
- `kind`, `kubectl`, `helm`, `docker`, `curl`, and `python3`.
- RAM license at `./license`.
- `OPENAI_API_KEY` exported in your shell or set in `.env`.
- Optional for load testing: `locust`.

Create and edit `.env` if you want persistent defaults:

```sh
cp env/ram.kind.env.example .env
```

Set a real `OPENAI_API_KEY` before first setup. Keep `.env`, `license`, and `.generated/` out of source control.

## First Setup

If you previously created `ram` with an older single-node kind config, recreate it so Redis Enterprise gets three worker nodes. If the cluster does not exist, this command is harmless.

```sh
make delete-cluster
```

Then run:

```sh
make up
```

`make up` creates or reuses the multi-node kind cluster, then deploys the stack. The deploy step installs the Redis Enterprise operator, creates the REC and REDBs, renders RAM config from REDB connection secrets, creates RAM Secrets, installs RAM, restarts RAM so Redis indexes are ensured, installs `kube-prometheus-stack`, applies RAM and Redis Enterprise ServiceMonitors, loads the RAM Grafana dashboard, and prints status.

`make up` is the combined path. The phases are also available separately as `make kind-up` and `make deploy-stack`.

The first run can take several minutes because Redis Enterprise images are large and the REC bootstraps three pods.

## Validate

Check that the stack is healthy:

```sh
make status
make monitoring-status
```

Expected high-level state:

- REC `rec`: `Running`
- REDB `ram-content`: `active`
- REDB `ram-jobs`: `active`
- RAM server deployment: Ready
- RAM worker deployment: Ready
- Prometheus and Grafana resources: Ready
- RAM and Redis Enterprise scrape targets: `up`

`make monitoring-status` shows the harness scrape targets by default. For the full Kubernetes target list, run `./scripts/monitoring-status.sh --all-targets`.

In one terminal, expose the local UIs:

```sh
make port-forward
```

In another terminal, run both smoke profiles:

```sh
make smoke-session
make smoke
```

`make smoke-session` checks health and session write/read. `make smoke` also creates and searches long-term memory, which calls the model provider.

Open these local UIs while testing:

- RAM API: `http://127.0.0.1:9000`
- Prometheus: `http://127.0.0.1:9090`
- Grafana: `http://127.0.0.1:3000`
- RAM Grafana dashboard: `http://127.0.0.1:3000/d/ram-harness/redis-agent-memory`
- Locust, after starting a load target: `http://127.0.0.1:8089`

`make port-forward` keeps RAM, Prometheus, and Grafana in one foreground process. If you only need part of it or have a local port conflict, run `./scripts/port-forward.sh --ram-only`, `./scripts/port-forward.sh --monitoring-only`, or override ports with the script flags.

Grafana credentials are generated by the Helm chart and stored in Kubernetes:

```sh
kubectl -n monitoring get secret ram-observability-grafana -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl -n monitoring get secret ram-observability-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## Daily Commands

```sh
make help            # Show all supported entrypoints
make kind-up         # Create/reuse the kind cluster only
make deploy-stack    # Deploy Redis Enterprise, RAM, and monitoring into the configured context
make status          # Redis Enterprise, RAM, pods, services, and port-forward status
make port-forward    # Expose RAM :9000, Prometheus :9090, and Grafana :3000
make monitoring-status        # Prometheus, Grafana, ServiceMonitors, and scrape targets
make smoke-session   # Health plus session write/read only
make smoke           # Full smoke test, including long-term memory/model calls
make logs            # RAM server and worker logs
make reset-data      # Flush RAM Redis databases and restart RAM
make load-working-memory     # Locust UI for working/session memory
make seed-ltm        # Seed long-term memory data for search load tests
make load-search     # Locust UI for session plus long-term memory search
make load-promotion  # Locust UI with RAM worker processing promotion jobs
make down            # Uninstall monitoring, RAM, and Redis Enterprise resources
make delete-cluster  # Delete the whole kind cluster
```

## How RAM Finds Redis

The Redis Enterprise database controller creates connection secrets for each REDB. [scripts/render-config.sh](./scripts/render-config.sh) reads those secrets and writes `.generated/memory-dataplane.config.yaml`.

The generated RAM config uses:

- `ram-content` REDB for RAM metadata and memory records.
- `ram-jobs` REDB for background Redis Streams jobs.

There is no manual Redis hostname, port, or password copying.

## Repo Layout

- [env/ram.kind.env.example](./env/ram.kind.env.example): local defaults you can copy to `.env`.
- [configs/](./configs/) and [k8s/](./k8s/): Helm values, Redis Enterprise databases, ServiceMonitors, and the RAM Grafana dashboard.
- [memory-dataplane.config.yaml](./memory-dataplane.config.yaml): RAM config template rendered into `.generated/`.
- [scripts/](./scripts/): implementation behind the Make targets.
- [locust/](./locust/) and [docs/load-testing.md](./docs/load-testing.md): load-test runner and deeper load-test notes.

## Load Tests

Set up the stack using this README first, then install Locust:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r locust/requirements.txt
```

Working memory is RAM session memory. The working-memory load profile only writes and reads these API paths:

```text
POST /v1/stores/{storeId}/session-memory/events
GET  /v1/stores/{storeId}/session-memory/{sessionId}
```

Each Locust user keeps one session. Writes append fixed-size events, while reads fetch the full session, so long working-memory runs intentionally create growing per-session read responses.

Reset test data before a clean run:

```sh
make reset-data
```

Then start or restart the local forwards in one terminal:

```sh
make port-forward
```

Start the working-memory load test from another terminal:

```sh
make load-working-memory
```

Every load target starts the Locust UI. Open exactly `http://127.0.0.1:8089`, enter user count and spawn rate, and start the test. Locust serves plain HTTP; `https://127.0.0.1:8089` will fail. The RAM host is prefilled as `http://127.0.0.1:9000`.

Stopping Locust can close in-flight requests while `kubectl port-forward` is still copying response data. That local broken-pipe condition is benign; leave `make port-forward` running while you start and stop load tests.

`make reset-data` flushes only the RAM content/job REDBs and restarts the RAM deployments. Prometheus, Grafana, ServiceMonitors, dashboards, and retained monitoring history are left in place; Grafana may show RAM counter resets around the restart.

If `make port-forward` was already running when you reset data, stop and restart it after the reset because the RAM pod is restarted.

Locust is intentionally request-load only. It does not scrape RAM `/metrics` or add synthetic internal metric rows. Use Locust for simulated-user request behavior and exported load-test reports.

Prometheus and Grafana are the internal time-series view for the same run. Use Grafana to watch RAM handler latency, Redis client command duration, Redis client pool waits/timeouts, Redis Enterprise metrics, Kubernetes pods/nodes, and scrape health.

The bundled Grafana dashboard is intentionally small and RAM-focused. For Redis Enterprise cluster, node, database, shard, and proxy dashboards, import Redis's official v2 Grafana dashboards from the [Redis Enterprise Prometheus/Grafana documentation](https://redis.io/docs/latest/integrate/prometheus-with-redis-enterprise/) instead of vendoring large third-party JSON into this harness.

Search and promotion are separate because they include long-term memory or model-backed worker behavior:

```sh
make reset-data
make seed-ltm
make load-search
make load-promotion
```

The working-memory and search profiles scale the RAM worker to zero so writes are not promoted during the test. Promotion jobs can backlog in Redis Streams during a large working-memory run; reset the stack or intentionally run `make load-promotion` when you want to measure worker processing.

Details are in [docs/load-testing.md](./docs/load-testing.md).

## Tear Down

Remove monitoring, RAM, and Redis Enterprise resources but keep the kind cluster:

```sh
make down
```

Delete the whole kind Kubernetes cluster:

```sh
make delete-cluster
```

## Production Notes

The kind flow keeps the same ordering you would use in AKS: Redis Enterprise operator, REC, REDBs, generated RAM config from REDB secrets, RAM Helm release, then ServiceMonitor-based observability. Production guidance is in [docs/production-hardening.md](./docs/production-hardening.md).
