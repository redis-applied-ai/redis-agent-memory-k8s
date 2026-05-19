# Redis Agent Memory Enterprise Harness

This is the source of truth for running this stack with kind.

## What This Is

This harness runs Redis Agent Memory (RAM) on kind using Redis Enterprise for Kubernetes. It is meant to validate the same deployment shape we would later use in AKS: Redis Enterprise operator, Redis Enterprise cluster, Redis Enterprise databases, generated database connection secrets, and a RAM Helm release.

Use it to prove RAM session memory, long-term memory, vector search, Redis Streams promotion jobs, OpenAI-backed embeddings/promotion, and basic load profiles before moving the pattern into a customer or cloud environment.

This is not a Redis Stack shortcut and does not run Redis Enterprise in standalone Docker. Redis is provisioned only through Kubernetes resources.

## What Runs

- A 4-node `kind` cluster: 1 control-plane and 3 workers.
- Redis Enterprise operator from `redis/redis-enterprise-operator`.
- RedisEnterpriseCluster `rec`.
- RedisEnterpriseDatabase `ram-content` for session memory, long-term memory, JSON, Search, and vectors.
- RedisEnterpriseDatabase `ram-jobs` for Redis Streams promotion jobs.
- RAM API server and RAM worker from the RAM Helm chart.
- OpenAI calls from RAM for embeddings and memory promotion.
- Optional Locust load tests.

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
```

The RAM API server handles request/response paths such as writing session events, reading working memory, creating long-term memories, and searching long-term memory. The RAM worker handles asynchronous promotion jobs from Redis Streams: it reads queued work, calls the model provider, creates embeddings, and stores extracted memories.

The stack is deliberately split into two phases:

- [scripts/kind-up.sh](./scripts/kind-up.sh): create or reuse the kind cluster.
- [scripts/deploy-stack.sh](./scripts/deploy-stack.sh): deploy Redis Enterprise, render RAM config, create RAM Secrets, and install RAM.

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

Set a real `OPENAI_API_KEY` before first setup. Keep `.env`, `license`, `.generated/`, and `results/` out of source control.

## First Setup

If you previously created `ram` with an older single-node kind config, recreate it so Redis Enterprise gets three worker nodes. If the cluster does not exist, this command is harmless.

```sh
make delete-cluster
```

Then run:

```sh
make up
```

`make up` creates or reuses the multi-node kind cluster, then deploys the stack. The deploy step installs the Redis Enterprise operator, creates the REC and REDBs, renders RAM config from REDB connection secrets, creates RAM Secrets, installs RAM, restarts RAM so Redis indexes are ensured, and prints status.

`make up` is the combined path. The phases are also available separately as `make kind-up` and `make deploy-stack`.

The first run can take several minutes because Redis Enterprise images are large and the REC bootstraps three pods.

## Validate

Check that Redis Enterprise and RAM are healthy:

```sh
make status
```

Expected high-level state:

- REC `rec`: `Running`
- REDB `ram-content`: `active`
- REDB `ram-jobs`: `active`
- RAM server deployment: Ready
- RAM worker deployment: Ready

In one terminal, expose the RAM API:

```sh
make port-forward
```

In another terminal, run both smoke profiles:

```sh
make smoke-session
make smoke
```

`make smoke-session` checks health and session write/read. `make smoke` also creates and searches long-term memory, which calls the model provider.

## Daily Commands

```sh
make help            # Show all supported entrypoints
make kind-up         # Create/reuse the kind cluster only
make deploy-stack    # Deploy Redis Enterprise and RAM into the configured context
make status          # Redis Enterprise, RAM, pods, services, and port-forward status
make port-forward    # Expose RAM at http://127.0.0.1:9000
make smoke-session   # Health plus session write/read only
make smoke           # Full smoke test, including long-term memory/model calls
make logs            # RAM server and worker logs
make load-working-memory     # Headless Locust test for working/session memory
make load-working-memory-ui  # Locust UI for working/session memory at http://127.0.0.1:8089
make seed-ltm        # Seed long-term memory data for search load tests
make load-search     # Session plus long-term memory search load test
make load-promotion  # Session load while the RAM worker processes promotion jobs
make down            # Uninstall RAM and Redis Enterprise resources
make delete-cluster  # Delete the whole kind cluster
```

## How RAM Finds Redis

The Redis Enterprise database controller creates connection secrets for each REDB. [scripts/render-config.sh](./scripts/render-config.sh) reads those secrets and writes `.generated/memory-dataplane.config.yaml`.

The generated RAM config uses:

- `ram-content` REDB for RAM metadata and memory records.
- `ram-jobs` REDB for background Redis Streams jobs.

Operators do not manually copy Redis hostnames, ports, or passwords.

## Configuration Files

- [env/ram.kind.env.example](./env/ram.kind.env.example): kind environment defaults.
- [k8s/kind.redis-enterprise.yaml](./k8s/kind.redis-enterprise.yaml): kind topology.
- [configs/redis-enterprise/operator.values.yaml](./configs/redis-enterprise/operator.values.yaml): Redis Enterprise operator and REC values.
- [k8s/redis-enterprise-databases.yaml](./k8s/redis-enterprise-databases.yaml): REDB definitions.
- [configs/values.ram.kind.yaml](./configs/values.ram.kind.yaml): RAM Helm values.
- [memory-dataplane.config.yaml](./memory-dataplane.config.yaml): RAM config template.

## Entry Point Scripts

- [scripts/kind-up.sh](./scripts/kind-up.sh): creates or reuses the kind cluster.
- [scripts/deploy-stack.sh](./scripts/deploy-stack.sh): installs Redis Enterprise and RAM.
- [scripts/render-config.sh](./scripts/render-config.sh): renders RAM config from REDB connection secrets and `OPENAI_API_KEY`.
- [scripts/create-ram-secrets.sh](./scripts/create-ram-secrets.sh): creates the RAM license and config Secrets.
- [scripts/install-ram.sh](./scripts/install-ram.sh): installs or upgrades the RAM Helm release.
- [scripts/down.sh](./scripts/down.sh): removes RAM, Redis Enterprise resources, and optionally the kind cluster.

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

Keep `make port-forward` running in another terminal, then run the headless working-memory test:

```sh
make load-working-memory
```

Or use the Locust UI:

```sh
make load-working-memory-ui
```

Open exactly `http://127.0.0.1:8089`, enter user count and spawn rate, and start the test. Locust serves plain HTTP; `https://127.0.0.1:8089` will fail. The RAM host is prefilled as `http://127.0.0.1:9000`.

Search and promotion are separate because they include long-term memory or model-backed worker behavior:

```sh
make seed-ltm
make load-search
make load-promotion
```

The working-memory and search profiles scale the RAM worker to zero so writes are not promoted during the test. Promotion jobs can backlog in Redis Streams during a large working-memory run; reset the stack or intentionally run `make load-promotion` when you want to measure worker processing.

Details are in [docs/load-testing.md](./docs/load-testing.md).

## Tear Down

Remove RAM and Redis Enterprise resources but keep the kind cluster:

```sh
make down
```

Delete the whole kind Kubernetes cluster:

```sh
make delete-cluster
```

## AKS Translation

The kind flow intentionally mirrors the AKS shape:

```text
Kubernetes -> Redis Enterprise operator -> REC -> REDBs -> REDB secrets -> RAM Helm release
```

For AKS, replace kind with AKS and a production storage class, then keep the operator, REC, REDB, secret-derived RAM config, and RAM Helm sequence. Production guidance is in [docs/production-hardening.md](./docs/production-hardening.md).
