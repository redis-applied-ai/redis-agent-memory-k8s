# Redis Agent Memory Enterprise Local Harness

This is the source of truth for running this stack locally.

## What This Is

This harness runs Redis Agent Memory (RAM) on local Kubernetes using Redis Enterprise for Kubernetes. It is meant to validate the same deployment shape we would later use in AKS: Redis Enterprise operator, Redis Enterprise cluster, Redis Enterprise databases, generated database connection secrets, and a RAM Helm release.

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

No Redis Enterprise license file is required for this local harness. Redis Enterprise starts with a local trial license; `make status` shows the license state and expiration date.

## Prerequisites

- Docker Desktop with enough resources for Redis Enterprise plus RAM. Start with at least 8 CPUs and 12-16 GB memory if Docker Desktop allows it.
- `kind`, `kubectl`, `helm`, `docker`, `curl`, and `python3`.
- RAM license at `./license`.
- `OPENAI_API_KEY` exported in your shell or set in `.env`.
- Optional for load testing: `locust`.

Create and edit `.env` if you want persistent local defaults:

```sh
cp env/ram.local.env.example .env
```

Set a real `OPENAI_API_KEY` before first setup. Keep `.env`, `license`, `.generated/`, and `results/` out of source control.

## First Setup

If you previously created `ram-local` with an older single-node kind config, recreate it so Redis Enterprise gets three worker nodes:

```sh
make delete-cluster
```

Then run:

```sh
make verify
make up
```

`make up` creates or reuses the multi-node kind cluster, installs the Redis Enterprise operator, creates the REC and REDBs, renders RAM config from REDB connection secrets, creates RAM Secrets, installs RAM, restarts RAM so Redis indexes are ensured, and prints status.

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

In one terminal, expose RAM locally:

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
make status          # Redis Enterprise, RAM, pods, services, and port-forward status
make redis-status    # Redis Enterprise operator, REC, REDB, pods, and services only
make port-forward    # Expose RAM at http://127.0.0.1:9000
make smoke-session   # Health plus session write/read only
make smoke           # Full smoke test, including long-term memory/model calls
make logs            # RAM server and worker logs
make harden          # Apply RAM PDBs and ServiceMonitor when supported
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

- [env/ram.local.env.example](./env/ram.local.env.example): local environment defaults.
- [k8s/kind.redis-enterprise.yaml](./k8s/kind.redis-enterprise.yaml): local kind topology.
- [configs/redis-enterprise/operator.values.yaml](./configs/redis-enterprise/operator.values.yaml): Redis Enterprise operator and REC values.
- [k8s/redis-enterprise-databases.yaml](./k8s/redis-enterprise-databases.yaml): REDB definitions.
- [configs/values.ram.local.yaml](./configs/values.ram.local.yaml): RAM Helm values.
- [memory-dataplane.config.yaml](./memory-dataplane.config.yaml): RAM config template.

## Load Tests

Set up the stack using this README first, then install Locust:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r locust/requirements.txt
```

Run the API/Redis baseline first:

```sh
make load-session
```

Search and promotion are separate because they make model-backed calls:

```sh
make seed-ltm
make load-search
make load-promotion
```

Details are in [docs/load-testing.md](./docs/load-testing.md).

## Tear Down

Remove RAM and Redis Enterprise resources but keep the kind cluster:

```sh
make down
```

Delete the whole local Kubernetes cluster:

```sh
make delete-cluster
```

## AKS Translation

The local flow intentionally mirrors the AKS shape:

```text
Kubernetes -> Redis Enterprise operator -> REC -> REDBs -> REDB secrets -> RAM Helm release
```

For AKS, replace kind with AKS and a production storage class, then keep the operator, REC, REDB, secret-derived RAM config, and RAM Helm sequence. Production guidance is in [docs/production-hardening.md](./docs/production-hardening.md).
