# 20 - Terraform Lab Foundation

## Purpose

This document describes the current Terraform baseline in this repository for the lab environment.

It covers:

- Terraform runtime and command wrappers
- Proxmox provider/auth wiring
- execution workflow before adding VM resources

## Current Status

Implemented in `terraform/environments/lab`:

- Terraform version constraint (`~> 1.14.5`)
- provider `bpg/proxmox` pinned by `.terraform.lock.hcl`
- provider auth via environment variables
- optional insecure TLS toggle via `TF_VAR_proxmox_insecure`
- Talos raw image download from official release URL
- Talos base template VM creation (default VMID `9000`)
- Talos Kubernetes VM provisioning from template (`3` control planes + `2` workers)

Not implemented yet:

- Talos OS machine configuration generation/apply
- Kubernetes bootstrap and post-bootstrap platform stack

## Auth Model

Proxmox authentication is expected via environment variables:

- `PROXMOX_VE_ENDPOINT` (example: `https://pve.example.lan:8006/`)
- `PROXMOX_VE_API_TOKEN` (`user@realm!tokenid=secret`)
- `TF_VAR_proxmox_insecure` (`true` only for self-signed certificates)

Recommended shell workflow:

1. Use `.env` + `.envrc` in `terraform/environments/lab`.
2. Use `direnv` to load variables automatically when entering the directory.
3. Never commit `.env` or `.envrc`.

## Commands

### Via Makefile (recommended)

```bash
make tf-init
make tf-validate
make tf-plan
```

### Via mise

```bash
mise run tf-init
mise run tf-validate
mise run tf-plan
```

These commands call Terraform with `-chdir=terraform/environments/lab` to avoid accidental runs from the wrong directory.

## Next Step

Next phase will bootstrap Talos/Kubernetes on the provisioned VMs.

Required inputs to proceed:

1. Talos machine config strategy (generated locally or managed artifact)
2. API endpoint strategy (temporary direct CP IP vs VIP)
3. bootstrap order and smoke tests (`talosctl`, `kubectl`)
4. base add-ons sequencing (CNI, ingress, storage, observability, GitOps)
