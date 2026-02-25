.DEFAULT_GOAL := help

ANSIBLE_DIR=ansible
TERRAFORM_LAB_DIR=terraform/environments/lab
TALOS_BOOTSTRAP_SCRIPT=scripts/talos-bootstrap.sh
TALOS_SYNC_SCRIPT=scripts/talos-sync-from-terraform.sh
TALOS_POST_BOOTSTRAP_SCRIPT=scripts/talos-post-bootstrap.sh
KUBE_VIP_SCRIPT=scripts/kube-vip.sh
HELM_RELEASE_SCRIPT=scripts/helm-release.sh

.PHONY: help list-releases pre-commit-install lint tf-init tf-validate tf-plan tf-apply tf-apply-auto tf-apply-replace talos-sync talos-generate talos-apply talos-bootstrap talos-post-bootstrap talos-all helm-apply helm-check helm-delete kube-vip-apply kube-vip-check kube-vip-recover kube-vip-delete ansible-proxmox-bootstrap ansible-proxmox-upgrade ansible-proxmox-tweaks ansible-proxmox-tuning ansible-proxmox-hardening

help: ## Show available make targets and usage examples
	@echo "Usage: make <target>"
	@echo
	@echo "Examples:"
	@echo "  make tf-plan"
	@echo "  make tf-apply-replace REPLACE='module.talos_proxmox_cluster.proxmox_virtual_environment_vm.k8s_node[\"cpk8s01\"]'"
	@echo "  make helm-apply RELEASE='kube-vip'"
	@echo
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-26s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

list-releases: ## List available Helm release directories under kubernetes/helm
	@if [ -d kubernetes/helm ]; then \
		find kubernetes/helm -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort; \
	else \
		echo "No kubernetes/helm directory found."; \
	fi

pre-commit-install: ## Install pre-commit hooks
	uv run pre-commit install

lint: ## Run full repository lint suite
	uv run pre-commit run --all-files

tf-init: ## Initialize Terraform lab environment
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-init

tf-validate: ## Validate Terraform lab configuration
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-validate

tf-plan: ## Show Terraform lab execution plan
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-plan

tf-apply: ## Apply Terraform lab changes (interactive approval)
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-apply

tf-apply-auto: ## Apply Terraform lab changes without approval prompt
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-apply-auto

tf-apply-replace: ## Force Terraform replacement for one or more resources via REPLACE
	@if [ -z "$(REPLACE)" ]; then \
		echo "Usage: make tf-apply-replace REPLACE='<resource1> <resource2> ...'"; \
		echo "Example: make tf-apply-replace REPLACE='proxmox_virtual_environment_vm.k8s_node[\"cpk8s01\"]'"; \
		exit 1; \
	fi
	@echo "Destructive operation: Terraform will recreate the following resources:"
	@for target in $(REPLACE); do \
		canonical_target=$$(printf '%s' "$$target" | sed -E 's/\[([[:alnum:]_-]+)\]/["\1"]/g'); \
		echo "  - $$canonical_target"; \
	done
	@set -eu; \
	set --; \
	for target in $(REPLACE); do \
		canonical_target=$$(printf '%s' "$$target" | sed -E 's/\[([[:alnum:]_-]+)\]/["\1"]/g'); \
		set -- "$$@" "-replace=$$canonical_target"; \
	done; \
	direnv exec $(TERRAFORM_LAB_DIR) terraform -chdir=$(TERRAFORM_LAB_DIR) apply "$$@"

talos-sync: ## Generate talos/cluster.generated.env from Terraform outputs
	mise exec -- $(TALOS_SYNC_SCRIPT)

talos-generate: talos-sync ## Generate Talos machine configs
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) generate

talos-apply: ## Apply rendered Talos configs to nodes
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) apply

talos-bootstrap: ## Bootstrap Talos cluster and refresh kubeconfig
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) bootstrap

talos-post-bootstrap: ## Run post-bootstrap health checks (etcd, nodes, kube-system)
	mise exec -- $(TALOS_POST_BOOTSTRAP_SCRIPT) check

talos-all: ## Run full Talos flow: generate, apply, bootstrap
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) all

helm-apply: ## Apply Helm release from kubernetes/helm/<release> via RELEASE
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-apply RELEASE='<release-name>'"; \
		echo "Example: make helm-apply RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) apply

helm-check: ## Check Helm release status via RELEASE
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-check RELEASE='<release-name>'"; \
		echo "Example: make helm-check RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) check

helm-delete: ## Delete Helm release via RELEASE
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-delete RELEASE='<release-name>'"; \
		echo "Example: make helm-delete RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) delete

kube-vip-apply: ## Apply kube-vip Helm release
	mise exec -- $(KUBE_VIP_SCRIPT) apply

kube-vip-check: ## Check kube-vip rollout and VIP API readiness
	mise exec -- $(KUBE_VIP_SCRIPT) check

kube-vip-recover: ## Recover kube-vip availability (restart kube-proxy + kube-vip)
	mise exec -- $(KUBE_VIP_SCRIPT) recover

kube-vip-delete: ## Delete kube-vip Helm release
	mise exec -- $(KUBE_VIP_SCRIPT) delete

ansible-proxmox-bootstrap: ## Run Ansible Proxmox bootstrap tasks
	@echo "Bootstrapping Proxmox host"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'bootstrap'

ansible-proxmox-upgrade: ## Run Ansible Proxmox upgrade tasks
	@echo "Upgrading Proxmox host"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'upgrade'

ansible-proxmox-tweaks: ## Run Ansible Proxmox tweaks tasks
	@echo "Applying Proxmox tweaks"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'tweaks'

ansible-proxmox-tuning: ## Run Ansible Proxmox tuning tasks
	@echo "Applying Proxmox tuning"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'tuning'

ansible-proxmox-hardening: ## Run Ansible Proxmox hardening tasks
	@echo "Applying Proxmox hardening"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'hardening'
