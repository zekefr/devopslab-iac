# devopslab-iac

Homelab infrastructure-as-code repository.

This repository contains the infrastructure definition for a personal DevOps lab
based on:

- Proxmox VE (PVE 9.x)
- Ansible (currently: Proxmox host bootstrap, tweaks, tuning, hardening, and upgrade)
- Terraform (currently: provider/auth foundation + Talos image/template workflow)
- Talos & Kubernetes (planned)
- GitOps (planned)

---

## Python Environment

This project uses:

- Python 3.13 (managed via `uv`)
- `ansible`
- `ansible-lint`
- `pre-commit`

The Python environment is fully isolated and reproducible via:

```bash
uv sync
```

To verify:

```bash
uv run python --version
```

## Pre-commit

Pre-commit is used to enforce:

- basic file hygiene
- YAML validation
- ansible-lint rules

Install hooks:

```bash
make pre-commit-install
```

Run manually:

```bash
make lint
```

## Terraform CLI Runtime

Terraform is managed via `mise`:

```bash
mise install
terraform version
```

Use repository targets to avoid running Terraform in the wrong directory:

```bash
make tf-init
make tf-validate
make tf-plan
```

## Scope (current stage)

- Implemented:
  - tooling (`uv`, pre-commit, ansible-lint)
  - Ansible scope for Proxmox host bootstrap/tweaks/tuning/hardening/upgrade
  - Terraform lab foundation (`bpg/proxmox` provider, auth wiring, lock file, command wrappers)
  - Talos image download + Talos base template VM creation in `terraform/environments/lab`
- Planned (not yet implemented): Terraform VM provisioning workflow, Talos/Kubernetes bootstrap, GitOps

## Documentation

- `docs/00-prereqs.md` - Environment prerequisites, lint workflow, and agent execution model
- `docs/10-proxmox-bootstrap.md` - Proxmox bootstrap/tweaks/tuning/hardening/upgrade concepts, commands, and troubleshooting
- `docs/20-terraform-lab-foundation.md` - Terraform lab foundation, auth model, and execution workflow

## Repository structure (current stage)

```text
.
├── ansible/        # Ansible code
├── terraform/      # Terraform code (lab environment foundation)
├── pyproject.toml  # Python project config (uv)
├── mise.toml       # Tool version pinning + Terraform task runners
├── uv.lock         # Locked dependencies
├── .pre-commit-config.yaml
├── .ansible-lint
├── Makefile
└── docs/           # Documentation
```

## Commit Convention

This project follows Conventional Commits:

- `feat`: new feature
- `fix`: bug fix
- `chore`: tooling / setup
- `docs`: documentation
- `refactor`: internal changes without behavior change
- `ci`: CI/CD changes
