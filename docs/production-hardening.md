# Production Hardening

The local harness now follows the same control-plane shape expected in AKS:

```text
Redis Enterprise operator -> RedisEnterpriseCluster -> RedisEnterpriseDatabase -> REDB connection secrets -> RAM Helm release
```

## Kubernetes

- Use a supported AKS version and a dedicated node pool for Redis Enterprise.
- Use a production storage class with the latency, reclaim, expansion, and backup behavior you want.
- Keep Redis Enterprise and RAM in namespaces with clear ownership. The local default puts them together for simplicity.
- Add CNI-specific NetworkPolicy after validating the operator, REC pods, webhook, services rigger, DNS, RAM, and model-provider egress paths. Do not copy a generic default-deny policy into AKS without testing those flows.
- Add metrics scraping for RAM and Redis Enterprise. The local `make harden` target applies RAM PDBs and applies ServiceMonitor only when the CRD exists.

## Redis Enterprise

- Use at least three Redis Enterprise nodes.
- Keep separate REDBs for RAM content and RAM job streams.
- Enable persistence, backup, and alerting for production REDBs.
- Use TLS and private endpoints. When REDBs require TLS, render RAM config with `rediss://` URLs and mount the private CA bundle through the RAM chart.
- Manage the Redis Enterprise license through Kubernetes Secret or your cloud secret manager.
- Monitor node memory, shard memory, proxy latency, Search/vector index memory, command latency, evictions, persistence, stream length, pending jobs, and oldest pending job age.

## RAM

- Keep separate server and worker deployments.
- Run at least two replicas for both server and worker.
- Keep the RAM Service internal unless a gateway or private ingress requires otherwise.
- Put external traffic behind a gateway or service mesh for OAuth/OIDC, quotas, rate limits, WAF rules, TLS, and body redaction.
- Store the RAM license, RAM config, and model provider credentials in a production secret manager.
- Keep generated RAM config out of source control.

## Load Tests

- Start with `make load-working-memory` to isolate RAM API and Redis Enterprise behavior.
- Run search and promotion profiles separately.
- Run the load generator inside the same private network for customer-scale tests rather than through a workstation port-forward.
