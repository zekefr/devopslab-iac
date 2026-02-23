ANSIBLE_DIR=ansible
TERRAFORM_LAB_DIR=terraform/environments/lab

.PHONY: pre-commit-install lint tf-init tf-validate tf-plan tf-apply tf-apply-auto ansible-proxmox-bootstrap ansible-proxmox-upgrade ansible-proxmox-tweaks ansible-proxmox-tuning ansible-proxmox-hardening

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
