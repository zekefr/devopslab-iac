# 10 - Proxmox Bootstrap and Upgrade

## Purpose

This document explains how the current Ansible scope works for Proxmox host bootstrap and upgrade.

It is written for human operators and AI agents (Codex/Claude) that need to understand both:

- conceptual model (what is executed and why)
- operational commands (how to run it safely)

## Conceptual Model

### Execution layers

The automation is split into four layers:

1. inventory: defines target hosts (`proxmox` group)
2. playbook: selects hosts and gates execution via tags
3. role: `proxmox` role orchestrates task files
4. task files: `bootstrap.yml` and `upgrade.yml`

### Why tag-gated execution exists

The playbook role include is tagged with `never`, `bootstrap`, `upgrade`.
This prevents accidental full runs and enforces explicit intent.

## Current File Map

```text
ansible/
├── ansible.cfg
├── inventory/lab/inventory.yml
├── playbooks/proxmox.yml
└── roles/proxmox/
    ├── defaults/main.yml
    └── tasks/
        ├── main.yml
        ├── bootstrap.yml
        └── upgrade.yml
```

## Inventory Basics

### Minimal host declaration (YAML)

This is the current shape expected by the playbook:

```yaml
all:
  children:
    proxmox:
      hosts:
        pve:
          ansible_host: 192.168.1.100
          ansible_user: root
```

Use SSH keys and secure host values per environment.

## Bootstrap Behavior

### What bootstrap does

`bootstrap` currently ensures:

- enterprise repositories are disabled (idempotent absence)
- no-subscription repository is present
- apt cache is updated
- base packages (`ca-certificates`, `curl`, `gnupg`) are installed

### Why this is idempotent

The enterprise repo files are enforced with `state: absent`, so if they reappear later, a new run removes them again.

## Upgrade Behavior

### What upgrade does

`upgrade` performs:

- full apt upgrade + cleanup
- reboot detection via `/var/run/reboot-required`
- controlled reboot only when both:
  - package state changed
  - reboot-required file exists

## Execution Commands

### Preferred Make targets

```bash
make ansible-proxmox-bootstrap
make ansible-proxmox-upgrade
```

### Equivalent direct Ansible commands

```bash
cd ansible
uv run ansible-playbook playbooks/proxmox.yml -t bootstrap
uv run ansible-playbook playbooks/proxmox.yml -t upgrade
```

### Validation commands before remote execution

```bash
make lint
cd ansible && uv run ansible-playbook --syntax-check playbooks/proxmox.yml
uv run ansible-lint ansible
```

## Variable Overrides

### Example runtime override (YAML vars file)

If you need a different Debian suite/repo in a non-default environment:

```yaml
proxmox_suite: trixie
proxmox_repo_url: http://download.proxmox.com/debian/pve
```

Then run:

```bash
cd ansible
uv run ansible-playbook playbooks/proxmox.yml -t bootstrap -e @vars/lab.yml
```

## Agent Guidance (Codex / Claude)

### Safe operating pattern

1. read `AGENTS.md` scope first
2. modify only required files
3. run lint + syntax checks
4. summarize with explicit file references

### Example operation contract (JSON)

```json
{
  "scope": "Ansible Proxmox bootstrap/upgrade only",
  "required_checks": [
    "make lint",
    "uv run ansible-lint ansible",
    "uv run ansible-playbook --syntax-check playbooks/proxmox.yml"
  ],
  "forbidden_actions": [
    "commit without explicit user request",
    "introduce Terraform/Talos/GitOps code"
  ]
}
```

## Troubleshooting

### Hook says ansible-lint skipped

Use current hook configuration that runs `uv run ansible-lint ansible` with `always_run: true`.

### SSH/auth errors on playbook run

Verify:

- host reachability
- `ansible_user`
- SSH keys/agent
- sudo/become requirements on target
