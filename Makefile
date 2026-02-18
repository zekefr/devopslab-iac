ANSIBLE_DIR=ansible

.PHONY: pre-commit-install lint ansible-proxmox-bootstrap ansible-proxmox-upgrade

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
