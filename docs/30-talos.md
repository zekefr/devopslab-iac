# 30 - Talos

## Table of Contents

- [Purpose](#purpose)
- [Current Assets](#current-assets)
- [Configuration File](#configuration-file)
- [Execution Flow](#execution-flow)
- [Practical Notes](#practical-notes)
- [Kube-VIP API HA](#kube-vip-api-ha)
- [Metrics Server](#metrics-server)
- [MetalLB](#metallb)
- [Traefik Ingress](#traefik-ingress)

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
- `scripts/kube-vip.sh`
- `scripts/metrics-server.sh`
- `scripts/metallb.sh`
- `talos/cluster.local.env.example`
- `kubernetes/helm/kube-vip/release.env`
- `kubernetes/helm/kube-vip/values.lab.yaml`
- `kubernetes/helm/metrics-server/release.env`
- `kubernetes/helm/metrics-server/values.lab.yaml`
- `kubernetes/helm/metallb/release.env`
- `kubernetes/helm/metallb/values.lab.yaml`
- `kubernetes/helm/metallb/ip-pool.lab.yaml`
- `kubernetes/helm/traefik/release.env`
- `kubernetes/helm/traefik/values.lab.yaml`
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

## Kube-VIP API HA

This repository provides declarative Helm-based kube-vip configuration for Kubernetes API HA in:

- `kubernetes/helm/kube-vip/release.env` (release metadata)
- `kubernetes/helm/kube-vip/values.lab.yaml` (environment values)

Current mode is API-only (no Service `LoadBalancer` handling):

- VIP address: `192.168.1.220`
- ARP/L2 mode
- leader election enabled
- Helm chart: `kube-vip/kube-vip` (release `kube-vip`)

Commands:

```bash
make helm-apply RELEASE='kube-vip'
make helm-check RELEASE='kube-vip'
make kube-vip-apply
make kube-vip-check
make kube-vip-recover
```

Optional removal:

```bash
make kube-vip-delete
```

Recommended cutover sequence:

1. Apply kube-vip and verify `https://192.168.1.220:6443/readyz`.
2. Update Terraform `k8s_cluster_endpoint` to `192.168.1.220`.
3. Run `make tf-plan && make tf-apply`.
4. Run `make talos-sync && make talos-generate && make talos-apply`.
5. Run `make talos-bootstrap && make talos-post-bootstrap`.

Recovery runbook (if VIP is not reachable after endpoint cutover):

```bash
make kube-vip-recover
```

`kube-vip-recover` performs a deterministic recovery sequence via a control-plane API server:

1. restart `kube-proxy` DaemonSet
2. wait for `kube-proxy` rollout
3. restart `kube-vip` DaemonSet
4. wait for `kube-vip` rollout
5. probe VIP API readiness

By default it auto-detects a fallback API server from `talos/cluster.generated.env`.
You can override it explicitly if needed:

```bash
KUBE_VIP_RECOVERY_API_SERVER=192.168.1.201 make kube-vip-recover
```

## Metrics Server

This repository provides declarative Helm-based metrics-server configuration in:

- `kubernetes/helm/metrics-server/release.env` (release metadata)
- `kubernetes/helm/metrics-server/values.lab.yaml` (environment values)

Current defaults:

- two replicas
- `--kubelet-insecure-tls` enabled (homelab-friendly Talos default)
- metrics resolution set to `15s`
- release namespace: `kube-system`

Commands:

```bash
make helm-apply RELEASE='metrics-server'
make helm-check RELEASE='metrics-server'
make metrics-server-apply
make metrics-server-check
```

Optional removal:

```bash
make metrics-server-delete
```

Validation:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
```

## MetalLB

This repository provides declarative Helm-based MetalLB configuration in:

- `kubernetes/helm/metallb/release.env` (release metadata)
- `kubernetes/helm/metallb/values.lab.yaml` (controller/speaker values)
- `kubernetes/helm/metallb/ip-pool.lab.yaml` (IPAddressPool + L2Advertisement)

Current defaults:

- namespace: `metallb-system`
- address pool: `192.168.1.230-192.168.1.239`
- L2 advertisement mode

Important:

- reserve/exclude the MetalLB pool range from your DHCP server to avoid IP conflicts.
- MetalLB speaker needs host networking/capabilities, so namespace `metallb-system` must run with Pod Security `privileged`.
  `make metallb-apply` handles this automatically.

Commands:

```bash
make helm-apply RELEASE='metallb'
make helm-check RELEASE='metallb'
make metallb-apply
make metallb-check
```

Optional removal:

```bash
make metallb-delete
```

Validation:

```bash
kubectl -n metallb-system get deployment controller
kubectl -n metallb-system get daemonset speaker
kubectl -n metallb-system get ipaddresspool,l2advertisement
kubectl get svc -A | grep LoadBalancer
```

## Traefik Ingress

This repository provides declarative Helm-based Traefik configuration in:

- `kubernetes/helm/traefik/release.env` (release metadata)
- `kubernetes/helm/traefik/values.lab.yaml` (environment values)

Current defaults:

- `DaemonSet` deployment
- service type `LoadBalancer` (requires MetalLB)
- fixed service IP: `192.168.1.230`
- default ingress class set to `traefik`

Commands:

```bash
make helm-apply RELEASE='traefik'
make helm-check RELEASE='traefik'
make traefik-apply
make traefik-check
```

Optional removal:

```bash
make traefik-delete
```

Validation:

```bash
kubectl -n kube-system get svc traefik -o wide
kubectl get ingressclass
```
