ANSIBLE_DIR=ansible

.PHONY: pre-commit-install lint ansible-proxmox-bootstrap ansible-proxmox-upgrade ansible-proxmox-tweaks ansible-proxmox-tuning ansible-proxmox-hardening

pre-commit-install:
	uv run pre-commit install

lint:
	uv run pre-commit run --all-files

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
