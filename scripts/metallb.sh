#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HELM_RELEASE_SCRIPT="${REPO_ROOT}/scripts/helm-release.sh"

METALLB_RELEASE_DIR="${METALLB_RELEASE_DIR:-${REPO_ROOT}/kubernetes/helm/metallb}"
METALLB_POOL_FILE="${METALLB_POOL_FILE:-${METALLB_RELEASE_DIR}/ip-pool.lab.yaml}"
METALLB_NAMESPACE="${METALLB_NAMESPACE:-metallb-system}"
METALLB_WAIT_TIMEOUT="${METALLB_WAIT_TIMEOUT:-180s}"
METALLB_CONTROLLER_DEPLOYMENT="${METALLB_CONTROLLER_DEPLOYMENT:-metallb-controller}"
METALLB_SPEAKER_DAEMONSET="${METALLB_SPEAKER_DAEMONSET:-metallb-speaker}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <apply|check|delete>

Environment overrides:
  METALLB_RELEASE_DIR   Helm release directory (default: kubernetes/helm/metallb)
  METALLB_POOL_FILE     Address pool manifest file (default: <release-dir>/ip-pool.lab.yaml)
  METALLB_NAMESPACE     Namespace (default: metallb-system)
  METALLB_WAIT_TIMEOUT  Rollout wait timeout (default: 180s)
  METALLB_CONTROLLER_DEPLOYMENT  Controller deployment name (default: metallb-controller)
  METALLB_SPEAKER_DAEMONSET      Speaker daemonset name (default: metallb-speaker)
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

validate_inputs() {
  if [[ ! -x "$HELM_RELEASE_SCRIPT" ]]; then
    echo "Missing or non-executable Helm release script: $HELM_RELEASE_SCRIPT" >&2
    exit 1
  fi

  if [[ ! -f "$METALLB_RELEASE_DIR/release.env" ]]; then
    echo "Missing MetalLB release config: $METALLB_RELEASE_DIR/release.env" >&2
    exit 1
  fi

  if [[ ! -f "$METALLB_RELEASE_DIR/values.lab.yaml" ]]; then
    echo "Missing MetalLB values file: $METALLB_RELEASE_DIR/values.lab.yaml" >&2
    exit 1
  fi

  if [[ ! -f "$METALLB_POOL_FILE" ]]; then
    echo "Missing MetalLB address pool manifest: $METALLB_POOL_FILE" >&2
    exit 1
  fi
}

ensure_namespace_privileged_psa() {
  if ! kubectl get namespace "$METALLB_NAMESPACE" >/dev/null 2>&1; then
    kubectl create namespace "$METALLB_NAMESPACE"
  fi

  # MetalLB speaker requires host networking/capabilities that violate baseline/restricted PSA.
  kubectl label namespace "$METALLB_NAMESPACE" \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged \
    --overwrite >/dev/null
}

apply_metallb() {
  echo "Ensuring namespace Pod Security labels for MetalLB in $METALLB_NAMESPACE"
  ensure_namespace_privileged_psa

  echo "Applying MetalLB Helm release from $METALLB_RELEASE_DIR"
  HELM_RELEASE_DIR="$METALLB_RELEASE_DIR" HELM_WAIT_TIMEOUT="$METALLB_WAIT_TIMEOUT" "$HELM_RELEASE_SCRIPT" apply

  echo "Waiting for MetalLB controller deployment rollout (${METALLB_CONTROLLER_DEPLOYMENT})"
  kubectl -n "$METALLB_NAMESPACE" rollout status "deployment/${METALLB_CONTROLLER_DEPLOYMENT}" --timeout="$METALLB_WAIT_TIMEOUT"

  echo "Waiting for MetalLB speaker daemonset rollout (${METALLB_SPEAKER_DAEMONSET})"
  kubectl -n "$METALLB_NAMESPACE" rollout status "daemonset/${METALLB_SPEAKER_DAEMONSET}" --timeout="$METALLB_WAIT_TIMEOUT"

  echo "Applying MetalLB address pool manifests from $METALLB_POOL_FILE"
  kubectl apply -f "$METALLB_POOL_FILE"

  check_metallb
}

check_metallb() {
  HELM_RELEASE_DIR="$METALLB_RELEASE_DIR" "$HELM_RELEASE_SCRIPT" check >/dev/null

  echo "MetalLB core workloads"
  kubectl -n "$METALLB_NAMESPACE" get deployment "$METALLB_CONTROLLER_DEPLOYMENT"
  kubectl -n "$METALLB_NAMESPACE" get daemonset "$METALLB_SPEAKER_DAEMONSET"

  echo "MetalLB namespace Pod Security labels"
  kubectl get namespace "$METALLB_NAMESPACE" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}{" "}{.metadata.labels.pod-security\.kubernetes\.io/audit}{" "}{.metadata.labels.pod-security\.kubernetes\.io/warn}{"\n"}'

  echo "MetalLB address pools and advertisements"
  kubectl -n "$METALLB_NAMESPACE" get ipaddresspool,l2advertisement
}

delete_metallb() {
  echo "Deleting MetalLB address pool manifests"
  kubectl delete -f "$METALLB_POOL_FILE" --ignore-not-found=true >/dev/null 2>&1 || true

  echo "Deleting MetalLB Helm release"
  HELM_RELEASE_DIR="$METALLB_RELEASE_DIR" "$HELM_RELEASE_SCRIPT" delete
}

main() {
  local action="${1:-}"
  require_cmd kubectl
  require_cmd helm
  validate_inputs

  case "$action" in
    apply)
      apply_metallb
      ;;
    check)
      check_metallb
      ;;
    delete)
      delete_metallb
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
