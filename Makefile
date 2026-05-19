SHELL := /usr/bin/env bash

-include .env
export

ENV  ?= local
ARGS ?=

.DEFAULT_GOAL := help

.PHONY: help provision validate credentials up deploy-stack status logs port-forward smoke smoke-session seed-ltm load-working-memory load-working-memory-ui load-search load-promotion loadtest down delete delete-cluster

help:
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "%-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

provision: ## Create cluster infrastructure  [ENV=local|aks]
	./scripts/$(ENV)-provision.sh

validate: ## Dry-run validate cluster infrastructure without deploying  [ENV=aks]
	./scripts/$(ENV)-provision.sh --what-if

credentials: ## Fetch cluster credentials  [ENV=aks]
	./scripts/$(ENV)-credentials.sh

up: ## Create cluster and install Redis Enterprise + RAM  [ENV=local|aks] [ARGS=--skip-provision]
	./scripts/$(ENV)-up.sh $(ARGS)

deploy-stack: ## Install Redis Enterprise + RAM into current context (local only)
	./scripts/deploy-stack.sh

status: ## Show Helm, pod, service, and port-forward status
	./scripts/status.sh

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

load-working-memory: ## Run working/session memory load with worker scaled to zero
	./scripts/worker.sh off
	./locust/run.sh --profile working-memory

load-working-memory-ui: ## Open Locust UI for working/session memory load
	./scripts/worker.sh off
	./locust/run.sh --profile working-memory --ui

load-search: ## Run session plus long-term search load profile
	./scripts/worker.sh off
	./locust/run.sh --profile search

load-promotion: ## Run promotion profile with worker enabled
	./scripts/worker.sh on
	./locust/run.sh --profile promotion

loadtest: ## Run Locust load test via the AKS load test VM  [ENV=aks]
	./scripts/$(ENV)-loadtest.sh

down: ## Uninstall RAM and Redis Enterprise  [ENV=local|aks]
	./scripts/$(ENV)-down.sh

delete: ## Destroy cluster infrastructure  [ENV=local|aks]
	./scripts/$(ENV)-delete.sh

delete-cluster: ## Delete the local kind cluster (alias: make delete ENV=local)
	./scripts/local-delete.sh
