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

- `scripts/talos-bootstrap.sh`
- `talos/cluster.env.example`
- `make` targets: `talos-generate`, `talos-apply`, `talos-bootstrap`, `talos-all`

Generated machine configs are written to:

- `talos/generated/` (ignored by Git)

## Configuration File

Create local cluster configuration:

```bash
cp talos/cluster.env.example talos/cluster.env
```

Populate:

- `CLUSTER_NAME`
- `CLUSTER_ENDPOINT` (temporary endpoint can be first control plane IP)
- `GATEWAY_IPV4`
- `DNS_SERVERS`
- `CONTROL_PLANE_NODES`
- `WORKER_NODES`
- `NODE_TARGET_IP`

Optional:

- `BOOTSTRAP_NODE`
- `NODE_APPLY_ENDPOINT` (temporary reachable IPs if nodes boot with DHCP first)

## Execution Flow

### Step-by-step

```bash
make talos-generate
make talos-apply
make talos-bootstrap
```

### One-shot

```bash
make talos-all
```

## Practical Notes

- `NODE_APPLY_ENDPOINT` should contain current/reachable node IPs at apply time.
- `NODE_TARGET_IP` should contain final static Talos IPs.
- `talosctl kubeconfig` is executed during bootstrap.
- Keep `talos/cluster.env` local-only (ignored by Git).
