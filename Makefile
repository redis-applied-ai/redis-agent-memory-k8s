SHELL := /usr/bin/env bash

-include .env
export

.DEFAULT_GOAL := help

.PHONY: help up kind-up deploy-stack status logs port-forward monitoring-status smoke smoke-session reset-data seed-ltm load-working-memory load-search load-promotion down delete-cluster

help:
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "%-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Create/reuse kind, then deploy Redis Enterprise, RAM, and monitoring
	./scripts/kind-up.sh
	./scripts/deploy-stack.sh

kind-up: ## Create/reuse the kind cluster
	./scripts/kind-up.sh

deploy-stack: ## Deploy Redis Enterprise, RAM, and monitoring into the configured context
	./scripts/deploy-stack.sh

status: ## Show Helm, pod, service, and port-forward status
	./scripts/status.sh

logs: ## Show recent RAM server and worker logs
	./scripts/logs.sh all

port-forward: ## Forward RAM API, Prometheus, and Grafana locally
	./scripts/port-forward.sh

monitoring-status: ## Show Prometheus, Grafana, ServiceMonitor, and scrape target status
	./scripts/monitoring-status.sh

smoke: ## Run end-to-end smoke test, including long-term memory/model calls
	./scripts/smoke-test.sh

smoke-session: ## Run health and session-memory smoke test only
	./scripts/smoke-test.sh --skip-ltm

reset-data: ## Flush RAM Redis databases and restart RAM
	./scripts/reset-data.sh

seed-ltm: ## Seed long-term memory for search load tests
	./scripts/seed-long-term-memory.sh --count $${RAM_SEED_COUNT:-100}

load-working-memory: ## Open Locust UI for working/session memory load
	./locust/run.sh --profile working-memory --worker off

load-search: ## Open Locust UI for session plus long-term search load
	./locust/run.sh --profile search --worker off

load-promotion: ## Open Locust UI with worker promotion enabled
	./locust/run.sh --profile promotion --worker on

down: ## Uninstall monitoring, RAM, and Redis Enterprise resources
	./scripts/down.sh

delete-cluster: ## Delete the whole kind cluster
	./scripts/down.sh --delete-cluster
