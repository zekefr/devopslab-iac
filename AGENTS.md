# AGENTS.md

This repository follows an incremental infrastructure-as-code approach.

## Environment

- Python 3.13 (managed via uv)
- Ansible >= 13.x
- ansible-lint >= 26.x
- pre-commit >= 4.x
- Terraform 1.14.5 (managed via mise)

All Python tooling must be executed via:

    uv run <command>

Do not assume system Python.

Terraform commands should use the pinned runtime from `mise`.

## Linting Rules

- Pre-commit must pass before commits
- Run `make lint` before proposing a commit
- For Terraform lab checks, run `make tf-init`, `make tf-validate`, and `make tf-plan`
- Commit messages must follow Conventional Commits (see `README.md`, section "Commit Convention")
- ansible-lint profile: basic (for now)
- Excluded paths are defined in `.ansible-lint`

## Scope

At this stage, tooling setup and an initial Ansible scope exist.
The repository now includes Ansible code for Proxmox host bootstrap and upgrade workflows.
The repository also includes a Terraform lab foundation for Proxmox (provider, auth wiring, lock file, command wrappers, Talos image download, and Talos base template VM).
Do not assume or create infrastructure outside this scope unless explicitly requested.

Future additions (not yet implemented):

- Expanded Proxmox host configuration (Ansible)
- Talos Kubernetes cluster
- GitOps configuration

Agents should avoid inventing infrastructure that does not yet exist.

## Terraform Execution Guardrails

- Prefer `make tf-init`, `make tf-validate`, and `make tf-plan` from repository root.
- Equivalent `mise` tasks are available (`mise run tf-init`, `mise run tf-validate`, `mise run tf-plan`).
- Avoid running bare `terraform validate` from repository root (it can validate an empty root config).

## Secrets Handling

- Proxmox API authentication must come from environment variables.
- `.env` and `.envrc` are local-only files and must never be committed.
- `direnv` is the recommended way to load per-directory Terraform auth variables.

## Git Hygiene

- Do not create commits unless explicitly requested by the user
- Do not push or rewrite history unless explicitly requested by the user
