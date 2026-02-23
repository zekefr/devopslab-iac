# 00 - Prerequisites

## Purpose

This document explains the minimum prerequisites to work safely in this repository, especially for AI agents like Codex or Claude.

The goal is to keep execution reproducible:

- one Python toolchain (`uv`)
- one Terraform CLI runtime (`mise`)
- one lint gate (`make lint`)
- one Ansible quality profile (`basic`)

## Required Toolchain

### Versions expected by the repo

- Python `3.13` (managed by `uv`)
- Ansible `>= 13.x`
- ansible-lint `>= 26.x`
- pre-commit `>= 4.x`
- Terraform `1.14.5` (managed by `mise`)

### Why `uv run` is mandatory

Commands must run inside the project environment so dependency versions stay consistent across machines and agents.

```bash
uv run <command>
```

Running tools directly from system Python can produce different lint and runtime behavior.

### Why `mise` is used for Terraform

Terraform is pinned in `mise.toml` so all operators/agents run the same binary version.

Use:

```bash
mise install
mise run tf-init
mise run tf-validate
mise run tf-plan
```

## Environment Bootstrap

### Sync dependencies

```bash
uv sync
```

### Verify core binaries from the project env

```bash
uv run python --version
uv run ansible --version
uv run ansible-lint --version
uv run pre-commit --version
terraform version
```

## Lint Workflow

### Install hooks once

```bash
make pre-commit-install
```

### Run full lint gate

```bash
make lint
```

`make lint` is the required check before proposing a commit.

### Terraform checks (lab environment)

```bash
make tf-init
make tf-validate
make tf-plan
```

Terraform commands are wrapped so they always target `terraform/environments/lab`.

## Agent-Oriented Execution Model (Codex / Claude)

### Conceptual loop

1. Read scope and constraints from `AGENTS.md`.
2. Apply minimal targeted changes.
3. Run validation (`make lint`, plus targeted checks when relevant).
4. Report findings with file/line references.

### Example task envelope (JSON)

This is a useful structure when handing work to an agent.

```json
{
  "goal": "Update Proxmox bootstrap tasks",
  "constraints": [
    "Use uv run for Python tooling",
    "Keep ansible-lint profile basic clean",
    "Do not create commits automatically"
  ],
  "checks": [
    "make lint",
    "uv run ansible-lint ansible"
  ]
}
```

## Quick Sanity Checklist

Before starting infra changes:

- `uv sync` completed
- `make lint` passes
- scope still matches `AGENTS.md`
