# --------------------------------------------------------------------------- #
# VCF 9.1 Greenfield Framework - stage driver
#
# All Infrastructure-as-Code lives under iac/. Every target that touches
# infrastructure takes STAGE=<stage-directory>:
#
#   make preflight
#   make plan  STAGE=10-management-domain
#   make apply STAGE=10-management-domain
#
# `make up` walks all Terraform stages in order (each one still asks for
# confirmation before applying).
# --------------------------------------------------------------------------- #

IAC         := iac
STAGES_DIR  := $(IAC)/stages
STAGES      := 10-management-domain 20-network-pools 30-host-commission \
               40-workload-domain 50-edge-cluster 60-supervisor

SITE_CONFIG ?= $(IAC)/config/site.yaml
STAGE       ?=

.PHONY: help preflight fmt validate init plan apply destroy up

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Stages (STAGE=): $(STAGES)"

preflight: ## Validate DNS, NTP and host reachability against site.yaml
	./$(IAC)/scripts/preflight.sh $(SITE_CONFIG)

fmt: ## Format all Terraform code
	terraform fmt -recursive $(IAC)/modules $(STAGES_DIR)

validate: ## terraform validate every stage (offline)
	@set -e; for stage in $(STAGES); do \
	  echo "== validating $(STAGES_DIR)/$$stage"; \
	  terraform -chdir=$(STAGES_DIR)/$$stage init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$(STAGES_DIR)/$$stage validate; \
	done

init: _require_stage ## terraform init one stage
	terraform -chdir=$(STAGES_DIR)/$(STAGE) init -input=false

plan: _require_stage ## terraform plan one stage
	terraform -chdir=$(STAGES_DIR)/$(STAGE) plan

apply: _require_stage ## terraform apply one stage
	terraform -chdir=$(STAGES_DIR)/$(STAGE) apply

destroy: _require_stage ## terraform destroy one stage (asks for confirmation)
	terraform -chdir=$(STAGES_DIR)/$(STAGE) destroy

up: preflight ## Run every Terraform stage in order (confirm each apply)
	@set -e; for stage in $(STAGES); do \
	  echo ""; echo "==================== $(STAGES_DIR)/$$stage ===================="; \
	  terraform -chdir=$(STAGES_DIR)/$$stage init -input=false >/dev/null; \
	  terraform -chdir=$(STAGES_DIR)/$$stage apply; \
	done

_require_stage:
	@if [ -z "$(STAGE)" ]; then \
	  echo "Set STAGE=<stage-directory>, e.g. make plan STAGE=10-management-domain"; \
	  exit 1; \
	fi
