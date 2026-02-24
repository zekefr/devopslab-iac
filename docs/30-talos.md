# 30 - Talos

## Table of Contents

- [Purpose](#purpose)
- [Current Assets](#current-assets)
- [Configuration File](#configuration-file)
- [Execution Flow](#execution-flow)
- [Practical Notes](#practical-notes)

## Purpose

This document explains how Talos bootstrap is automated in this repository.

It covers:

- declarative cluster inputs
- generation and patching of Talos machine configs
- apply/bootstrap execution flow

## Current Assets

Talos automation is implemented with:

- `scripts/talos-sync-from-terraform.sh`
- `scripts/talos-bootstrap.sh`
- `scripts/talos-post-bootstrap.sh`
- `talos/cluster.local.env.example`
- `make` targets: `talos-sync`, `talos-generate`, `talos-apply`, `talos-bootstrap`, `talos-post-bootstrap`, `talos-all`

Generated machine configs are written to:

- `talos/generated/` (ignored by Git)

## Configuration File

Generate cluster configuration from Terraform:

```bash
make talos-sync
```

This writes:

- `talos/cluster.generated.env` (ignored by Git)

Data comes from Terraform output (`talos_cluster_env`) and includes:

- `CLUSTER_NAME`
- `CLUSTER_ENDPOINT`
- `GATEWAY_IPV4`
- `DNS_SERVERS`
- `CONTROL_PLANE_NODES`
- `WORKER_NODES`
- `NODE_TARGET_IP`

Note:

- `make talos-sync` reads Terraform state outputs, so run `make tf-apply` first after Terraform changes.

Optional:

- create `talos/cluster.local.env` from `talos/cluster.local.env.example`
- set `BOOTSTRAP_NODE` only if you want to override the default first control plane

## Execution Flow

### Step-by-step

```bash
make talos-sync
make talos-generate
make talos-apply
make talos-bootstrap
make talos-post-bootstrap
```

### One-shot

```bash
make talos-all
```

## Practical Notes

- `NODE_TARGET_IP` should contain final static Talos IPs and is also used for `talosctl apply-config`.
- `talosctl kubeconfig` is executed during bootstrap.
- `make talos-post-bootstrap` runs non-destructive health checks (etcd members, node readiness, `kube-system` pods).
- `talos/cluster.generated.env` is generated and should not be edited manually.
- `talos/cluster.local.env` is optional local-only override (ignored by Git).
