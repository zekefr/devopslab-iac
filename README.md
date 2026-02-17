# devopslab-iac

Homelab infrastructure-as-code repository.

This repository contains the infrastructure definition for a personal DevOps lab
based on:

- Proxmox VE (PVE 9.x)
- Ansible (host bootstrap & configuration)
- Terraform (planned)
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

## Repository structure (current stage)

```text
.
├── ansible/        # Ansible code (to be added)
├── pyproject.toml  # Python project config (uv)
├── uv.lock         # Locked dependencies
├── .pre-commit-config.yaml
├── .ansible-lint
├── Makefile
└── docs/           # Documentation (to be added and expanded)
```

## Commit Convention

This project follows Conventional Commits:

- `feat`: new feature
- `fix`: bug fix
- `chore`: tooling / setup
- `docs`: documentation
- `refactor`: internal changes without behavior change
- `ci`: CI/CD changes
