# 20 - Terraform

## Table of Contents

- [Purpose](#purpose)
- [Current Scope](#current-scope)
- [Directory](#directory)
- [Runtime and Command Wrappers](#runtime-and-command-wrappers)
- [Authentication and Direnv Setup](#authentication-and-direnv-setup)
- [Terraform Workflow](#terraform-workflow)
- [Destructive Replace Apply](#destructive-replace-apply)
- [Variables and Network Model](#variables-and-network-model)
- [Guardrails](#guardrails)
- [DHCP Reservations for Pinned MAC Addresses](#dhcp-reservations-for-pinned-mac-addresses)
- [Talos Integration Notes](#talos-integration-notes)
- [Troubleshooting](#troubleshooting)

## Purpose

This document is the single reference for Terraform usage in this repository.

It covers:

- Proxmox provider/auth wiring
- template and node provisioning workflow
- command wrappers (`make` and `mise`)
- network planning and MAC pinning

## Current Scope

Implemented in `terraform/environments/lab`:

- Terraform version constraint (`~> 1.14.5`)
- provider `bpg/proxmox` pinned by `.terraform.lock.hcl`
- Proxmox auth via environment variables
- Talos image download from official release URL
- Talos template VM creation (default VMID `9000`)
- Talos Kubernetes VMs provisioning from template (`3` control planes + `2` workers)
- per-node static metadata (`role`, planned IP, VMID, pinned MAC address)
- input guardrails (variable validation, global checks, template destroy protection)
- reusable module extraction (`terraform/modules/talos-proxmox-cluster`)

## Directory

```text
terraform/environments/lab/
├── versions.tf
├── providers.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars.example
├── terraform.tfvars        # local, ignored
├── .env.example
├── .env                    # local, ignored
├── .envrc.example
├── .envrc                  # local, ignored
└── .terraform.lock.hcl

terraform/modules/talos-proxmox-cluster/
├── main.tf
├── variables.tf
├── outputs.tf
└── checks.tf
```

## Runtime and Command Wrappers

Recommended commands from repository root:

```bash
make tf-init
make tf-validate
make tf-plan
make tf-apply
make tf-apply-auto
make tf-apply-replace REPLACE='<resource1> <resource2>'
```

Equivalent `mise` tasks:

```bash
mise run tf-init
mise run tf-validate
mise run tf-plan
mise run tf-apply
mise run tf-apply-auto
```

These wrappers use `-chdir=terraform/environments/lab` to avoid accidental execution in the wrong directory.

## Authentication and Direnv Setup

Proxmox credentials are loaded via environment variables:

- `PROXMOX_VE_ENDPOINT` (example: `https://pve.example.lan:8006/`)
- `PROXMOX_VE_API_TOKEN` (`user@realm!tokenid=secret`)
- `TF_VAR_proxmox_insecure` (`true` only for self-signed certs)

Recommended setup:

1. Create local files:

```bash
cd terraform/environments/lab
cp .env.example .env
cp .envrc.example .envrc
```

2. Edit `.env` with real values.
3. Enable `direnv` in your shell.
4. Authorize the directory once:

```bash
direnv allow
```

Never commit `.env` or `.envrc`.

## Terraform Workflow

1. Initialize:

```bash
make tf-init
```

2. Validate:

```bash
make tf-validate
```

3. Review plan:

```bash
make tf-plan
```

4. Apply:

```bash
make tf-apply
# or non-interactive
make tf-apply-auto
```

## Destructive Replace Apply

Use this only when you explicitly want Terraform to destroy and recreate one or more resources.

```bash
make tf-apply-replace REPLACE='proxmox_virtual_environment_vm.k8s_node["cpk8s01"]'
```

For multiple resources:

```bash
make tf-apply-replace REPLACE='proxmox_virtual_environment_vm.k8s_node["cpk8s01"] proxmox_virtual_environment_vm.k8s_node["cpk8s02"]'
```

The Make target prints the list, warns it is destructive, then runs `terraform apply -replace=...` with the standard Terraform confirmation prompt.
For convenience, bracket keys without quotes are also accepted (for example `k8s_node[cpk8s01]`) and normalized automatically.

## Variables and Network Model

Create local overrides:

```bash
cd terraform/environments/lab
cp terraform.tfvars.example terraform.tfvars
```

`k8s_nodes` is the node map used by Terraform provisioning. Each node includes:

- `role` (`control-plane` or `worker`)
- `ip` (planned/static Talos IP)
- `vm_id`
- `mac_address` (pinned NIC MAC in Proxmox)

Important behavior:

- `k8s_nodes[*].ip` is planned metadata for Talos/static networking.
- Proxmox clone itself does not configure guest static IP for Talos.
- Talos network configuration is handled in the Talos phase (`docs/30-talos.md`).

Provider-specific notes:

- `talos_image_content_type` stays `iso` for compressed Talos `raw.zst`.
- This workflow uses `disk.file_id` and requires SSH access to the Proxmox node from Terraform runtime.
- Terraform exposes `talos_cluster_env` output used by `make talos-sync` as Talos single-source input (state must be updated via `make tf-apply`).

## Guardrails

Terraform now enforces additional protections:

- input validation on critical fields (`ip`, `vm_id`, `mac_address`, VLAN, ports, sizing)
- uniqueness checks for node IPs, VMIDs, and MAC addresses
- global checks to ensure cluster shape is coherent (control plane presence, worker presence, odd multi-CP count, endpoint not on worker IP)
- template protection with `prevent_destroy` on `proxmox_virtual_environment_vm.talos_template`

If you intentionally need to destroy/recreate the Talos template, remove or temporarily disable `prevent_destroy` in `main.tf`.

## DHCP Reservations for Pinned MAC Addresses

Terraform now pins one MAC address per Kubernetes VM (`k8s_nodes[*].mac_address`).

To make node bring-up deterministic after VM recreation:

1. Create DHCP reservations on your DHCP server/router for each pinned MAC.
2. Map each MAC to the expected temporary boot IP (or final IP if you use a single addressing strategy).
3. Keep Talos `NODE_TARGET_IP` aligned with your reserved addressing strategy.

Without DHCP reservations, a recreated VM can still get unexpected temporary IPs, even with stable VM names.

## Talos Integration Notes

- Terraform provisions VM shape/template only.
- Talos bootstrap/config apply is documented separately in `docs/30-talos.md`.
- Talos cluster input is generated from Terraform output (`make talos-sync`), so node/IP inventory is single-source.

## Troubleshooting

- `Missing Proxmox VE API Endpoint`:
  - check `.env` values and `direnv` loading.
- `tls: certificate required` during Talos apply:
  - this is Talos API auth phase, not Terraform.
- wrong node IPs after recreation:
  - verify DHCP reservations for pinned MACs.
