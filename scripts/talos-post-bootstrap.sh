#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CONFIG_FILE="${TALOS_CLUSTER_FILE:-${REPO_ROOT}/talos/cluster.generated.env}"
LOCAL_CONFIG_FILE="${TALOS_CLUSTER_LOCAL_FILE:-${REPO_ROOT}/talos/cluster.local.env}"
TALOS_CLIENT_CONFIG="${TALOS_CLIENT_CONFIG:-${REPO_ROOT}/talos/generated/base/talosconfig}"
KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-300s}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <check>

Environment overrides:
  TALOS_CLUSTER_FILE        Path to generated cluster config file (default: talos/cluster.generated.env)
  TALOS_CLUSTER_LOCAL_FILE  Path to optional local override file (default: talos/cluster.local.env)
  TALOS_CLIENT_CONFIG       Path to talosconfig (default: talos/generated/base/talosconfig)
  KUBECTL_WAIT_TIMEOUT      Timeout for kubectl wait node readiness (default: 300s)
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

load_config() {
  local action="${1:-}"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Missing generated config file: $CONFIG_FILE" >&2
    echo "Generate it from Terraform: make talos-sync" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LOCAL_CONFIG_FILE"
  fi

  : "${CLUSTER_ENDPOINT:?CLUSTER_ENDPOINT is required in $CONFIG_FILE}"

  if [[ ! "$(declare -p CONTROL_PLANE_NODES 2>/dev/null || true)" =~ ^declare\ -a ]]; then
    echo "CONTROL_PLANE_NODES must be a bash array in $CONFIG_FILE" >&2
    exit 1
  fi
  if [[ ! "$(declare -p NODE_TARGET_IP 2>/dev/null || true)" =~ ^declare\ -A ]]; then
    echo "NODE_TARGET_IP must be a bash associative array in $CONFIG_FILE" >&2
    exit 1
  fi
  if ((${#CONTROL_PLANE_NODES[@]} == 0)); then
    echo "CONTROL_PLANE_NODES cannot be empty in $CONFIG_FILE" >&2
    exit 1
  fi
  if ((${#NODE_TARGET_IP[@]} == 0)); then
    echo "NODE_TARGET_IP cannot be empty in $CONFIG_FILE" >&2
    exit 1
  fi

  if [[ -n "$action" ]]; then
    "$action"
  fi
}

get_node_target_ip() {
  local node="$1"
  local map_decl
  local node_re

  node_re="$(printf '%s' "$node" | sed -E 's/[][(){}.^$*+?|\\/]/\\&/g')"
  map_decl="$(declare -p NODE_TARGET_IP 2>/dev/null || true)"

  if [[ "${TALOS_DEBUG:-0}" == "1" ]]; then
    echo "DEBUG node=${node} node_re=${node_re}" >&2
    echo "DEBUG map_decl=${map_decl}" >&2
  fi

  if [[ "$map_decl" =~ \[$node_re\]=\"([^\"]+)\" ]]; then
    RESOLVED_NODE_TARGET_IP="${BASH_REMATCH[1]}"
    if [[ "${TALOS_DEBUG:-0}" == "1" ]]; then
      echo "DEBUG resolved_ip=${RESOLVED_NODE_TARGET_IP}" >&2
    fi
    return 0
  fi

  return 1
}

require_talosconfig() {
  if [[ ! -s "$TALOS_CLIENT_CONFIG" ]]; then
    echo "Missing or empty talosconfig: $TALOS_CLIENT_CONFIG" >&2
    echo "Run: make talos-generate && make talos-bootstrap" >&2
    exit 1
  fi
}

check_cluster() {
  require_cmd talosctl
  require_cmd kubectl
  require_talosconfig

  local bootstrap_node bootstrap_ip preferred_bootstrap_node node
  bootstrap_node=""
  bootstrap_ip=""
  preferred_bootstrap_node="${BOOTSTRAP_NODE:-}"
  RESOLVED_NODE_TARGET_IP=""

  if [[ -n "$preferred_bootstrap_node" ]]; then
    preferred_bootstrap_node="$(printf '%s' "$preferred_bootstrap_node" | tr -d '[:space:]')"
    if get_node_target_ip "$preferred_bootstrap_node"; then
      bootstrap_ip="$RESOLVED_NODE_TARGET_IP"
      bootstrap_node="$preferred_bootstrap_node"
    fi
  fi

  if [[ -z "$bootstrap_ip" ]]; then
    for node in "${CONTROL_PLANE_NODES[@]}"; do
      if get_node_target_ip "$node"; then
        bootstrap_ip="$RESOLVED_NODE_TARGET_IP"
        bootstrap_node="$node"
        break
      fi
    done
  fi

  if [[ -z "$bootstrap_ip" || -z "$bootstrap_node" ]]; then
    echo "Unable to resolve any control-plane IP from NODE_TARGET_IP." >&2
    exit 1
  fi

  echo "Checking etcd membership via ${bootstrap_node} (${bootstrap_ip})"
  talosctl --talosconfig "$TALOS_CLIENT_CONFIG" -n "$bootstrap_ip" -e "$bootstrap_ip" etcd members

  echo "Waiting for all Kubernetes nodes to be Ready (timeout: ${KUBECTL_WAIT_TIMEOUT})"
  kubectl wait --for=condition=Ready node --all --timeout="${KUBECTL_WAIT_TIMEOUT}"

  echo "Current node status"
  kubectl get nodes -o wide

  echo "Current kube-system workload status"
  kubectl -n kube-system get pods -o wide
}

main() {
  local action="${1:-}"
  case "$action" in
    check)
      load_config check_cluster
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
