# Redis Agent Memory Enterprise Harness

This harness runs Redis Agent Memory (RAM) on Kubernetes using Redis Enterprise for Kubernetes. It supports three environments selected via `ENV=`:

| `ENV=` | Cluster | Provisioner | Use |
|--------|---------|-------------|-----|
| `local` (default) | kind (local Docker) | — | Day-to-day development |
| `aks-tf` | Azure Kubernetes Service | Terraform (**preferred**) | Cloud validation, load testing, demos |
| `aks` | Azure Kubernetes Service | Bicep | Legacy; use `aks-tf` for new deployments |

All `make` targets that create or destroy infrastructure accept `ENV=`. Installation, smoke tests, and load tests are cluster-agnostic and work without an `ENV` flag once the cluster is running.

## What This Is

This harness runs Redis Agent Memory (RAM) on Kubernetes using Redis Enterprise for Kubernetes. It supports local development on kind and cloud deployment on AKS (via Terraform or Bicep). All environments use the same deployment shape: Redis Enterprise operator, Redis Enterprise cluster, Redis Enterprise databases, generated database connection secrets, and a RAM Helm release.

Use it to prove RAM session memory, long-term memory, vector search, Redis Streams promotion jobs, OpenAI-backed embeddings/promotion, and basic load profiles before moving the pattern into a customer or cloud environment.

This is not a Redis Stack shortcut and does not run Redis Enterprise in standalone Docker. Redis is provisioned only through Kubernetes resources.

## ENV= Pattern

All infrastructure targets accept an optional `ENV=` flag. The default is `local`:

```sh
make up                    # kind cluster + install everything
make up ENV=aks-tf         # AKS cluster via Terraform + install everything (preferred)
make up ENV=aks            # AKS cluster via Bicep + install everything (legacy)

make down ENV=aks-tf       # uninstall RAM and Redis Enterprise (AKS)
make delete ENV=aks-tf     # destroy Terraform-managed infrastructure

make delete                # delete kind cluster
```

The install scripts (`deploy-stack.sh`, `render-config.sh`, `install-ram.sh`) are cluster-agnostic. The `ENV=` flag only affects cluster provisioning and which Helm values and REDB manifests are used.

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

### kind (ENV=local)

- Docker Desktop with at least 8 CPUs and 12-16 GB memory.
- `kind`, `kubectl`, `helm`, `docker`, `curl`, and `python3`.
- RAM license at `./license`.
- `OPENAI_API_KEY` exported in your shell or set in `.env`.
- Optional for load testing: `locust`.

```sh
cp env/ram.kind.env.example .env
```

### AKS — ENV=aks-tf (preferred) and ENV=aks

All of the above, plus:
- Azure CLI (`az`) authenticated to a subscription with permission to create resource groups and AKS clusters.
- Terraform >= 1.5 (`brew install terraform`) for `ENV=aks-tf`.
- No local Docker resources needed for the cluster itself.

**Terraform (preferred):**
```sh
cp env/ram.aks-tf.env.example .env
# edit AKS_RESOURCE_GROUP, AKS_CLUSTER_NAME, AKS_LOCATION,
# AKS_ADMIN_SSH_PUBLIC_KEY, and OPENAI_API_KEY
```

**Bicep (legacy):**
```sh
cp env/ram.aks.env.example .env
# edit AKS_RESOURCE_GROUP, AKS_CLUSTER_NAME, AKS_LOCATION,
# AKS_ADMIN_SSH_PUBLIC_KEY, and OPENAI_API_KEY
```

Set a real `OPENAI_API_KEY` before first setup. Keep `.env`, `license`, `.generated/`, and `results/` out of source control.

## First Setup

### kind (ENV=local)

If you previously created the `ram` cluster with an older single-node kind config, recreate it so Redis Enterprise gets three worker nodes. If the cluster does not exist, this command is harmless.

```sh
make delete-cluster
```

Then run:

```sh
make up
```

`make up` creates or reuses the multi-node kind cluster, then deploys the stack. The deploy step installs the Redis Enterprise operator, creates the REC and REDBs, renders RAM config from REDB connection secrets, creates RAM Secrets, installs RAM, restarts RAM so Redis indexes are ensured, and prints status.

`make up` is the combined path. The phases are also available separately as `make provision` (kind cluster only) and `make deploy-stack` (install only, into whatever context is active).

The first run can take several minutes because Redis Enterprise images are large and the REC bootstraps three pods.

### AKS — Terraform (ENV=aks-tf, preferred)

Optionally preview what Terraform will create before spending anything:

```sh
make validate ENV=aks-tf
```

This runs `terraform plan` and shows all resources that would be created.

Then deploy everything:

```sh
make up ENV=aks-tf
```

`make up ENV=aks-tf` runs the full sequence:

1. `terraform init && terraform apply` — provisions all Azure resources (`infra/terraform/`)
2. `az aks get-credentials` — sets the kubectl context
3. Installs Redis Enterprise operator, creates the REC and REDBs
4. Renders RAM config, creates RAM Secrets, installs RAM
5. Creates the RAM internal load balancer service

Terraform creates:
- Resource group
- AKS cluster: 2-node system pool + 3-node Redis Enterprise pool
- Load test VM (Ubuntu 22.04, Locust pre-installed) with a public IP for SSH
- Dedicated VNet for the load test VM, peered with the AKS node VNet so the VM can reach the RAM internal load balancer
- Internal load balancer service for RAM (`redis-agent-memory-ilb`) — the VM hits RAM at `http://<ilb-ip>:9000` without port-forwarding

Provisioning takes 8-12 minutes. Node sizes and counts are configurable via `.env`.

To re-deploy into an existing cluster without re-provisioning:

```sh
make up ENV=aks-tf ARGS=--skip-provision
```

Or run the phases individually:

```sh
make provision ENV=aks-tf   # Terraform only
make credentials ENV=aks-tf # fetch kubeconfig
make deploy-stack            # install into current context
```

To run a load test from the load test VM:

```sh
make loadtest ENV=aks-tf
```

This discovers the VM's public IP and the ILB's private IP, copies the Locust files to the VM, and runs Locust headlessly over SSH.

### AKS — Bicep (ENV=aks, legacy)

`ENV=aks` uses Azure Bicep for infrastructure provisioning. Prefer `ENV=aks-tf` for new deployments — Terraform handles VNet peering natively and has better state management. The Bicep path remains for reference.

```sh
make validate ENV=aks   # az deployment group create --what-if
make up ENV=aks         # provision via Bicep + full install
```

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
make help                    # Show all supported entrypoints
make provision               # Create kind cluster (make provision ENV=aks for AKS)
make credentials ENV=aks     # Fetch AKS kubeconfig credentials
make deploy-stack            # Install Redis Enterprise + RAM into current context
make status                  # Redis Enterprise, RAM, pods, services, and port-forward status
make port-forward            # Expose RAM at http://127.0.0.1:9000
make smoke-session           # Health plus session write/read only
make smoke                   # Full smoke test, including long-term memory/model calls
make logs                    # RAM server and worker logs
make load-working-memory     # Headless Locust test for working/session memory
make load-working-memory-ui  # Locust UI for working/session memory at http://127.0.0.1:8089
make seed-ltm                # Seed long-term memory data for search load tests
make load-search             # Session plus long-term memory search load test
make load-promotion          # Session load while the RAM worker processes promotion jobs
make down                    # Uninstall RAM and Redis Enterprise (add ENV=aks for AKS)
make delete                  # Destroy cluster (add ENV=aks to delete Azure resource group)
make delete-cluster          # Alias: make delete ENV=local
```

## How RAM Finds Redis

The Redis Enterprise database controller creates connection secrets for each REDB. [scripts/render-config.sh](./scripts/render-config.sh) reads those secrets and writes `.generated/memory-dataplane.config.yaml`.

The generated RAM config uses:

- `ram-content` REDB for RAM metadata and memory records.
- `ram-jobs` REDB for background Redis Streams jobs.

Operators do not manually copy Redis hostnames, ports, or passwords.

## Configuration Files

| File | ENV | Purpose |
|------|-----|---------|
| `env/ram.kind.env.example` | local | kind environment variable defaults |
| `env/ram.aks-tf.env.example` | aks-tf | AKS + Terraform environment variable defaults |
| `env/ram.aks.env.example` | aks | AKS + Bicep environment variable defaults (legacy) |
| `k8s/kind.redis-enterprise.yaml` | local | kind cluster topology |
| `infra/terraform/` | aks-tf | Terraform configuration for AKS + load test VM + VNet peering |
| `infra/aks/main.bicep` | aks | AKS Bicep entry point (legacy) |
| `infra/aks/modules/` | aks | AKS, VNet, and load test VM Bicep modules (legacy) |
| `configs/redis-enterprise/operator.values.yaml` | local | Redis Enterprise operator and REC values |
| `configs/redis-enterprise/operator.values.aks.yaml` | aks, aks-tf | REC values — production sizing, standard storage |
| `k8s/redis-enterprise-databases.yaml` | local | REDB definitions — no persistence |
| `k8s/redis-enterprise-databases.aks.yaml` | aks, aks-tf | REDB definitions — `aofEverySecond`, replication enabled |
| `k8s/ram-internal-lb.aks.yaml` | aks, aks-tf | Internal LoadBalancer service for RAM (load test VM access) |
| `configs/values.ram.kind.yaml` | local | RAM Helm values |
| `configs/values.ram.aks.yaml` | aks, aks-tf | RAM Helm values — autoscaling, production sizing |
| `memory-dataplane.config.yaml` | all | RAM config template |

## Entry Point Scripts

Shared (env-agnostic):
- [scripts/deploy-stack.sh](./scripts/deploy-stack.sh): installs Redis Enterprise and RAM into the active context.
- [scripts/render-config.sh](./scripts/render-config.sh): renders RAM config from REDB secrets and `OPENAI_API_KEY`.
- [scripts/create-ram-secrets.sh](./scripts/create-ram-secrets.sh): creates the RAM license and config Secrets.
- [scripts/install-ram.sh](./scripts/install-ram.sh): installs or upgrades the RAM Helm release.
- [scripts/down.sh](./scripts/down.sh): uninstalls RAM and Redis Enterprise resources.

Local (kind):
- [scripts/local-up.sh](./scripts/local-up.sh): kind cluster + deploy-stack.
- [scripts/local-provision.sh](./scripts/local-provision.sh): create or reuse the kind cluster.
- [scripts/local-down.sh](./scripts/local-down.sh): uninstall RAM and Redis Enterprise from kind.
- [scripts/local-delete.sh](./scripts/local-delete.sh): delete the kind cluster.

AKS — Terraform (preferred):
- [scripts/aks-tf-up.sh](./scripts/aks-tf-up.sh): provision via Terraform + fetch credentials + deploy-stack + ILB.
- [scripts/aks-tf-provision.sh](./scripts/aks-tf-provision.sh): `terraform init && apply` (or `plan` with `--what-if`).
- [scripts/aks-tf-credentials.sh](./scripts/aks-tf-credentials.sh): `az aks get-credentials`.
- [scripts/aks-tf-down.sh](./scripts/aks-tf-down.sh): uninstall RAM and Redis Enterprise from AKS.
- [scripts/aks-tf-delete.sh](./scripts/aks-tf-delete.sh): `terraform destroy`.
- [scripts/aks-loadtest.sh](./scripts/aks-loadtest.sh): run Locust from the load test VM against the internal load balancer.

AKS — Bicep (legacy):
- [scripts/aks-up.sh](./scripts/aks-up.sh): provision via Bicep + fetch credentials + deploy-stack + ILB.
- [scripts/aks-provision.sh](./scripts/aks-provision.sh): create resource group, deploy Bicep, set up VNet peering.
- [scripts/aks-credentials.sh](./scripts/aks-credentials.sh): `az aks get-credentials`.
- [scripts/aks-down.sh](./scripts/aks-down.sh): uninstall RAM and Redis Enterprise from AKS.
- [scripts/aks-delete.sh](./scripts/aks-delete.sh): delete the Azure resource group.

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

### kind

Remove RAM and Redis Enterprise resources but keep the kind cluster:

```sh
make down
```

Delete the kind cluster entirely:

```sh
make delete-cluster
```

### AKS — Terraform (ENV=aks-tf)

Uninstall RAM and Redis Enterprise from the cluster (cluster remains):

```sh
make down ENV=aks-tf
```

Destroy all Terraform-managed infrastructure:

```sh
make delete ENV=aks-tf
```

This runs `terraform destroy -auto-approve` and removes all Azure resources.

### AKS — Bicep (ENV=aks, legacy)

Uninstall RAM and Redis Enterprise from the cluster (cluster remains):

```sh
make down ENV=aks
```

Delete the entire Azure resource group:

```sh
make delete ENV=aks
```

`make delete ENV=aks` is async — it returns immediately. Check progress with:

```sh
az group show --name ram-aks-rg --query properties.provisioningState -o tsv
```

## Adding New Environments

The `ENV=` pattern is designed to extend. To add GKE, EKS, or another environment:

1. Add `infra/<env>/` with the infrastructure-as-code for that provider.
2. Add `scripts/<env>-provision.sh`, `<env>-credentials.sh`, `<env>-up.sh`, `<env>-down.sh`, `<env>-delete.sh`.
3. Add `configs/redis-enterprise/operator.values.<env>.yaml` and `configs/values.ram.<env>.yaml`.
4. Add `k8s/redis-enterprise-databases.<env>.yaml` if the REDB config differs.
5. Add `env/ram.<env>.env.example`.

The shared install scripts (`deploy-stack.sh`, `render-config.sh`, `install-ram.sh`) need no changes.

## Production Hardening

Production guidance is in [docs/production-hardening.md](./docs/production-hardening.md).
