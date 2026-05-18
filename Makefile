SHELL := /usr/bin/env bash

-include .env
export

.DEFAULT_GOAL := help

.PHONY: help up harden status redis-status logs port-forward smoke smoke-session seed-ltm load-session load-search load-promotion promotion-on promotion-off verify down delete-cluster

help:
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Create/reuse kind, install Redis Enterprise, install RAM
	./scripts/up.sh

harden: ## Apply optional PDBs and ServiceMonitor when supported
	./scripts/apply-hardening.sh

status: ## Show Helm, pod, service, and port-forward status
	./scripts/status.sh

redis-status: ## Show Redis Enterprise operator, REC, REDB, pods, and services
	./scripts/redis-enterprise-status.sh

logs: ## Show recent RAM server and worker logs
	./scripts/logs.sh all

port-forward: ## Forward RAM API to http://127.0.0.1:9000
	./scripts/port-forward-ram.sh

smoke: ## Run end-to-end smoke test, including long-term memory/model calls
	./scripts/smoke-test.sh

smoke-session: ## Run health and session-memory smoke test only
	./scripts/smoke-test.sh --skip-ltm

seed-ltm: ## Seed long-term memory for search load tests
	./scripts/seed-long-term-memory.sh --count $${RAM_SEED_COUNT:-100}

load-session: ## Run API/Redis load baseline with worker scaled to zero
	./scripts/worker.sh off
	./locust/run-local.sh --profile session

load-search: ## Run session plus long-term search load profile
	./scripts/worker.sh off
	./locust/run-local.sh --profile search

load-promotion: ## Run promotion profile with worker enabled
	./scripts/worker.sh on
	./locust/run-local.sh --profile promotion

promotion-on: ## Enable RAM worker promotion jobs
	./scripts/worker.sh on

promotion-off: ## Disable RAM worker promotion jobs
	./scripts/worker.sh off

verify: ## Verify chart and container image artifacts exist
	./scripts/verify-artifacts.sh

down: ## Uninstall RAM and Redis Enterprise resources
	./scripts/down.sh

delete-cluster: ## Delete the whole local kind cluster
	./scripts/down.sh --delete-cluster
