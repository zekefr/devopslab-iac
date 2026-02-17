# AGENTS.md

This repository follows an incremental infrastructure-as-code approach.

## Environment

- Python 3.13 (managed via uv)
- Ansible >= 13.x
- ansible-lint >= 26.x
- pre-commit >= 4.x

All Python tooling must be executed via:

    uv run <command>

Do not assume system Python.

## Linting Rules

- Pre-commit must pass before commits
- Run `make lint` before proposing a commit
- Commit messages must follow Conventional Commits (see `README.md`, section "Commit Convention")
- ansible-lint profile: basic (for now)
- Excluded paths are defined in `.ansible-lint`

## Scope

At this stage, only tooling setup exists.
No infrastructure definitions should be assumed.
Do not create infrastructure code/directories (Ansible, Terraform, Talos, GitOps) unless explicitly requested.

Future additions (not yet implemented):

- Proxmox host bootstrap (Ansible)
- VM provisioning (Terraform)
- Talos Kubernetes cluster
- GitOps configuration

Agents should avoid inventing infrastructure that does not yet exist.

## Git Hygiene

- Do not create commits unless explicitly requested by the user
- Do not push or rewrite history unless explicitly requested by the user
