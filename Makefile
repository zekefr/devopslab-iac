ANSIBLE_DIR=ansible
TERRAFORM_LAB_DIR=terraform/environments/lab
TALOS_BOOTSTRAP_SCRIPT=scripts/talos-bootstrap.sh
TALOS_SYNC_SCRIPT=scripts/talos-sync-from-terraform.sh
TALOS_POST_BOOTSTRAP_SCRIPT=scripts/talos-post-bootstrap.sh
KUBE_VIP_SCRIPT=scripts/kube-vip.sh
HELM_RELEASE_SCRIPT=scripts/helm-release.sh

.PHONY: pre-commit-install lint tf-init tf-validate tf-plan tf-apply tf-apply-auto tf-apply-replace talos-sync talos-generate talos-apply talos-bootstrap talos-post-bootstrap talos-all helm-apply helm-check helm-delete kube-vip-apply kube-vip-check kube-vip-recover kube-vip-delete ansible-proxmox-bootstrap ansible-proxmox-upgrade ansible-proxmox-tweaks ansible-proxmox-tuning ansible-proxmox-hardening

pre-commit-install:
	uv run pre-commit install

lint:
	uv run pre-commit run --all-files

tf-init:
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-init

tf-validate:
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-validate

tf-plan:
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-plan

tf-apply:
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-apply

tf-apply-auto:
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-apply-auto

tf-apply-replace:
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

talos-sync:
	mise exec -- $(TALOS_SYNC_SCRIPT)

talos-generate: talos-sync
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) generate

talos-apply:
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) apply

talos-bootstrap:
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) bootstrap

talos-post-bootstrap:
	mise exec -- $(TALOS_POST_BOOTSTRAP_SCRIPT) check

talos-all:
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) all

helm-apply:
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-apply RELEASE='<release-name>'"; \
		echo "Example: make helm-apply RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) apply

helm-check:
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-check RELEASE='<release-name>'"; \
		echo "Example: make helm-check RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) check

helm-delete:
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-delete RELEASE='<release-name>'"; \
		echo "Example: make helm-delete RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) delete

kube-vip-apply:
	mise exec -- $(KUBE_VIP_SCRIPT) apply

kube-vip-check:
	mise exec -- $(KUBE_VIP_SCRIPT) check

kube-vip-recover:
	mise exec -- $(KUBE_VIP_SCRIPT) recover

kube-vip-delete:
	mise exec -- $(KUBE_VIP_SCRIPT) delete

ansible-proxmox-bootstrap:
	@echo "Bootstrapping Proxmox host"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'bootstrap'

ansible-proxmox-upgrade:
	@echo "Upgrading Proxmox host"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'upgrade'

ansible-proxmox-tweaks:
	@echo "Applying Proxmox tweaks"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'tweaks'

ansible-proxmox-tuning:
	@echo "Applying Proxmox tuning"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'tuning'

ansible-proxmox-hardening:
	@echo "Applying Proxmox hardening"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'hardening'
