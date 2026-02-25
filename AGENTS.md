# AGENTS.md

Operational rules for agents working in this repository.

## Read First

Before changing code, read the relevant documentation:

- Prerequisites and tooling: [`docs/00-prereqs.md`](docs/00-prereqs.md)
- Proxmox: [`docs/10-proxmox.md`](docs/10-proxmox.md)
- Terraform: [`docs/20-terraform.md`](docs/20-terraform.md)
- Talos: [`docs/30-talos.md`](docs/30-talos.md)

If docs and code differ, prioritize the current code behavior and propose a doc update.

## Runtime and Tooling

- Python runtime is managed by `uv` (Python 3.13).
- Terraform and cluster CLIs are managed by `mise`.
- Never assume system-level Python/tooling versions.

Python commands must run via:

    uv run <command>

Terraform commands should use the pinned runtime from `mise` (directly or via `make`).

## Mandatory Validation

Run before proposing a commit:

- `make lint`

Current lint scope includes:

- pre-commit hygiene checks
- `ansible-lint`
- `terraform fmt -check`
- `terraform validate` (lab environment)
- `tflint` (lab environment)

## Terraform Guardrails

- Prefer root targets: `make tf-init`, `make tf-validate`, `make tf-plan`.
- Equivalent tasks exist: `mise run tf-init|tf-validate|tf-plan`.
- Avoid running bare Terraform from repo root when targeting lab infra.
- Primary lab root is `terraform/environments/lab`.

## Talos Guardrails

- Use the scripted flow (`scripts/talos-bootstrap.sh`) via Make targets:
  - `make talos-sync`
  - `make talos-generate`
  - `make talos-apply`
  - `make talos-bootstrap`
  - `make talos-post-bootstrap`
- kube-vip API HA is managed with:
  - `make kube-vip-apply`
  - `make kube-vip-check`
  - `make kube-vip-recover`
  - `make kube-vip-delete`
- metrics-server is managed with:
  - `make metrics-server-apply`
  - `make metrics-server-check`
  - `make metrics-server-delete`
- Helm releases should use the standardized release layout:
  - `kubernetes/helm/<release>/release.env`
  - `kubernetes/helm/<release>/values.lab.yaml`
  - generic targets: `make helm-apply RELEASE='<release>'`, `make helm-check RELEASE='<release>'`, `make helm-delete RELEASE='<release>'`
- Treat `talos/cluster.generated.env` as generated local data (not committed).
- Treat `talos/cluster.local.env` as local operator overrides (not committed).
- Treat `talos/generated/` as generated artifacts (not committed).

## Secrets and Local Files

- Proxmox auth must come from environment variables.
- Never commit local credential files:
  - `terraform/environments/lab/.env`
  - `terraform/environments/lab/.envrc`
  - `talos/cluster.generated.env`
  - `talos/cluster.local.env`
- `direnv` is the recommended per-directory env loader for Terraform auth.

## Scope Boundaries

Current implemented scope:

- Ansible workflows for Proxmox host bootstrap/upgrade/tuning/hardening.
- Terraform lab foundation for Proxmox + Talos template + Talos node provisioning.
- Talos bootstrap automation scripts and docs.
- kube-vip API HA Helm values and operational workflow.
- metrics-server Helm values and operational workflow.

Do not invent or apply infrastructure outside this scope unless explicitly requested.

## Git Hygiene

- Do not create commits unless explicitly requested by the user.
- Do not push, rewrite history, or amend commits unless explicitly requested.
- Commit messages must follow Conventional Commits (see `README.md`).
