#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HELM_RELEASE_SCRIPT="${REPO_ROOT}/scripts/helm-release.sh"

KUBE_VIP_RELEASE_DIR="${KUBE_VIP_RELEASE_DIR:-${REPO_ROOT}/kubernetes/helm/kube-vip}"
KUBE_VIP_NAMESPACE="${KUBE_VIP_NAMESPACE:-kube-system}"
KUBE_VIP_DAEMONSET_NAME="${KUBE_VIP_DAEMONSET_NAME:-kube-vip}"
KUBE_VIP_WAIT_TIMEOUT="${KUBE_VIP_WAIT_TIMEOUT:-180s}"
KUBE_VIP_ADDRESS="${KUBE_VIP_ADDRESS:-192.168.1.220}"
KUBE_VIP_RECOVERY_API_SERVER="${KUBE_VIP_RECOVERY_API_SERVER:-}"
TALOS_CLUSTER_FILE="${TALOS_CLUSTER_FILE:-${REPO_ROOT}/talos/cluster.generated.env}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <apply|check|recover|delete>

Environment overrides:
  KUBE_VIP_RELEASE_DIR          Helm release directory (default: kubernetes/helm/kube-vip)
  KUBE_VIP_NAMESPACE      Namespace (default: kube-system)
  KUBE_VIP_DAEMONSET_NAME DaemonSet name (default: kube-vip)
  KUBE_VIP_WAIT_TIMEOUT   Rollout wait timeout (default: 180s)
  KUBE_VIP_ADDRESS        API VIP address (default: 192.168.1.220)
  KUBE_VIP_RECOVERY_API_SERVER  API server IP used for recovery operations
                                (default: first control-plane IP from talos/cluster.generated.env)
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

  if [[ ! -f "$KUBE_VIP_RELEASE_DIR/release.env" ]]; then
    echo "Missing kube-vip release config: $KUBE_VIP_RELEASE_DIR/release.env" >&2
    exit 1
  fi

  if [[ ! -f "$KUBE_VIP_RELEASE_DIR/values.lab.yaml" ]]; then
    echo "Missing kube-vip values file: $KUBE_VIP_RELEASE_DIR/values.lab.yaml" >&2
    exit 1
  fi

  if ! [[ "$KUBE_VIP_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "KUBE_VIP_ADDRESS must be an IPv4 address. Got: $KUBE_VIP_ADDRESS" >&2
    exit 1
  fi
}

resolve_recovery_api_server() {
  if [[ -n "$KUBE_VIP_RECOVERY_API_SERVER" ]]; then
    printf "%s" "$KUBE_VIP_RECOVERY_API_SERVER"
    return 0
  fi

  if [[ -f "$TALOS_CLUSTER_FILE" ]]; then
    local detected_server
    detected_server="$(TALOS_CLUSTER_FILE="$TALOS_CLUSTER_FILE" bash -c '
      set -euo pipefail
      # shellcheck disable=SC1090
      source "$TALOS_CLUSTER_FILE"
      cp="${CONTROL_PLANE_NODES[0]}"
      printf "%s" "${NODE_TARGET_IP[$cp]}"
    ' 2>/dev/null || true)"
    if [[ -n "$detected_server" ]]; then
      printf "%s" "$detected_server"
      return 0
    fi
  fi

  return 1
}

kubectl_recovery() {
  local recovery_server="$1"
  shift
  kubectl --server="https://${recovery_server}:6443" --insecure-skip-tls-verify=true "$@"
}

apply_kube_vip() {
  echo "Applying kube-vip Helm release from $KUBE_VIP_RELEASE_DIR"
  HELM_RELEASE_DIR="$KUBE_VIP_RELEASE_DIR" HELM_WAIT_TIMEOUT="$KUBE_VIP_WAIT_TIMEOUT" "$HELM_RELEASE_SCRIPT" apply

  echo "Waiting for kube-vip DaemonSet rollout"
  kubectl -n "$KUBE_VIP_NAMESPACE" rollout status "daemonset/${KUBE_VIP_DAEMONSET_NAME}" --timeout="$KUBE_VIP_WAIT_TIMEOUT"

  check_kube_vip
}

check_kube_vip() {
  HELM_RELEASE_DIR="$KUBE_VIP_RELEASE_DIR" "$HELM_RELEASE_SCRIPT" check >/dev/null

  echo "kube-vip DaemonSet status"
  kubectl -n "$KUBE_VIP_NAMESPACE" get daemonset "$KUBE_VIP_DAEMONSET_NAME"

  echo "kube-vip pods"
  kubectl -n "$KUBE_VIP_NAMESPACE" get pods -l app.kubernetes.io/name=kube-vip -o wide

  if command -v curl >/dev/null 2>&1; then
    echo "Kubernetes API readiness via VIP https://${KUBE_VIP_ADDRESS}:6443/readyz"
    curl -sk --max-time 5 "https://${KUBE_VIP_ADDRESS}:6443/readyz" || true
    echo
  else
    echo "curl not available, skipping HTTPS VIP readiness probe."
  fi
}

recover_kube_vip() {
  local recovery_server
  if ! recovery_server="$(resolve_recovery_api_server)"; then
    echo "Unable to determine recovery API server IP." >&2
    echo "Set KUBE_VIP_RECOVERY_API_SERVER explicitly, example:" >&2
    echo "  KUBE_VIP_RECOVERY_API_SERVER=192.168.1.201 make kube-vip-recover" >&2
    exit 1
  fi

  echo "Running kube-vip recovery via API server ${recovery_server}"
  kubectl_recovery "$recovery_server" -n "$KUBE_VIP_NAMESPACE" get daemonset kube-proxy "$KUBE_VIP_DAEMONSET_NAME"

  echo "Restarting kube-proxy DaemonSet"
  kubectl_recovery "$recovery_server" -n "$KUBE_VIP_NAMESPACE" rollout restart daemonset/kube-proxy
  kubectl_recovery "$recovery_server" -n "$KUBE_VIP_NAMESPACE" rollout status daemonset/kube-proxy --timeout="$KUBE_VIP_WAIT_TIMEOUT"

  echo "Restarting kube-vip DaemonSet"
  kubectl_recovery "$recovery_server" -n "$KUBE_VIP_NAMESPACE" rollout restart "daemonset/${KUBE_VIP_DAEMONSET_NAME}"
  kubectl_recovery "$recovery_server" -n "$KUBE_VIP_NAMESPACE" rollout status "daemonset/${KUBE_VIP_DAEMONSET_NAME}" --timeout="$KUBE_VIP_WAIT_TIMEOUT"

  echo "kube-vip pods after recovery"
  kubectl_recovery "$recovery_server" -n "$KUBE_VIP_NAMESPACE" get pods -l app.kubernetes.io/name=kube-vip -o wide

  if command -v curl >/dev/null 2>&1; then
    echo "Kubernetes API readiness via VIP https://${KUBE_VIP_ADDRESS}:6443/readyz"
    curl -sk --max-time 5 "https://${KUBE_VIP_ADDRESS}:6443/readyz" || true
    echo
  fi
}

delete_kube_vip() {
  HELM_RELEASE_DIR="$KUBE_VIP_RELEASE_DIR" "$HELM_RELEASE_SCRIPT" delete
}

main() {
  local action="${1:-}"
  require_cmd kubectl
  require_cmd helm
  validate_inputs

  case "$action" in
    apply)
      apply_kube_vip
      ;;
    check)
      check_kube_vip
      ;;
    recover)
      recover_kube_vip
      ;;
    delete)
      delete_kube_vip
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
