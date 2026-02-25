#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
HELM_RELEASE_SCRIPT="${REPO_ROOT}/scripts/helm-release.sh"

METRICS_SERVER_RELEASE_DIR="${METRICS_SERVER_RELEASE_DIR:-${REPO_ROOT}/kubernetes/helm/metrics-server}"
METRICS_SERVER_NAMESPACE="${METRICS_SERVER_NAMESPACE:-kube-system}"
METRICS_SERVER_DEPLOYMENT_NAME="${METRICS_SERVER_DEPLOYMENT_NAME:-metrics-server}"
METRICS_SERVER_WAIT_TIMEOUT="${METRICS_SERVER_WAIT_TIMEOUT:-180s}"
METRICS_SERVER_API_RETRIES="${METRICS_SERVER_API_RETRIES:-30}"
METRICS_SERVER_API_RETRY_DELAY="${METRICS_SERVER_API_RETRY_DELAY:-5}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <apply|check|delete>

Environment overrides:
  METRICS_SERVER_RELEASE_DIR     Helm release directory (default: kubernetes/helm/metrics-server)
  METRICS_SERVER_NAMESPACE       Namespace (default: kube-system)
  METRICS_SERVER_DEPLOYMENT_NAME Deployment name (default: metrics-server)
  METRICS_SERVER_WAIT_TIMEOUT    Rollout wait timeout (default: 180s)
  METRICS_SERVER_API_RETRIES     Metrics API readiness retries (default: 30)
  METRICS_SERVER_API_RETRY_DELAY Retry delay in seconds (default: 5)
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

  if [[ ! -f "$METRICS_SERVER_RELEASE_DIR/release.env" ]]; then
    echo "Missing metrics-server release config: $METRICS_SERVER_RELEASE_DIR/release.env" >&2
    exit 1
  fi

  if [[ ! -f "$METRICS_SERVER_RELEASE_DIR/values.lab.yaml" ]]; then
    echo "Missing metrics-server values file: $METRICS_SERVER_RELEASE_DIR/values.lab.yaml" >&2
    exit 1
  fi
}

wait_for_metrics_api() {
  local attempt=1

  while [[ "$attempt" -le "$METRICS_SERVER_API_RETRIES" ]]; do
    if kubectl get --raw '/apis/metrics.k8s.io/v1beta1/nodes' >/dev/null 2>&1; then
      echo "Metrics API is ready."
      return 0
    fi

    echo "Metrics API not ready yet (${attempt}/${METRICS_SERVER_API_RETRIES}), retrying in ${METRICS_SERVER_API_RETRY_DELAY}s..."
    sleep "$METRICS_SERVER_API_RETRY_DELAY"
    attempt=$((attempt + 1))
  done

  echo "Metrics API did not become ready in time." >&2
  return 1
}

apply_metrics_server() {
  echo "Applying metrics-server Helm release from $METRICS_SERVER_RELEASE_DIR"
  HELM_RELEASE_DIR="$METRICS_SERVER_RELEASE_DIR" HELM_WAIT_TIMEOUT="$METRICS_SERVER_WAIT_TIMEOUT" "$HELM_RELEASE_SCRIPT" apply

  echo "Waiting for metrics-server deployment rollout"
  kubectl -n "$METRICS_SERVER_NAMESPACE" rollout status "deployment/${METRICS_SERVER_DEPLOYMENT_NAME}" --timeout="$METRICS_SERVER_WAIT_TIMEOUT"

  check_metrics_server
}

check_metrics_server() {
  HELM_RELEASE_DIR="$METRICS_SERVER_RELEASE_DIR" "$HELM_RELEASE_SCRIPT" check >/dev/null

  echo "metrics-server deployment status"
  kubectl -n "$METRICS_SERVER_NAMESPACE" get deployment "$METRICS_SERVER_DEPLOYMENT_NAME"

  echo "metrics-server pods"
  kubectl -n "$METRICS_SERVER_NAMESPACE" get pods -l app.kubernetes.io/name=metrics-server -o wide

  echo "metrics APIService status"
  kubectl get apiservice v1beta1.metrics.k8s.io -o wide

  wait_for_metrics_api

  if kubectl top nodes >/dev/null 2>&1; then
    echo "kubectl top nodes"
    kubectl top nodes
  else
    echo "Warning: metrics API is up, but 'kubectl top nodes' is not available yet." >&2
  fi
}

delete_metrics_server() {
  HELM_RELEASE_DIR="$METRICS_SERVER_RELEASE_DIR" "$HELM_RELEASE_SCRIPT" delete
}

main() {
  local action="${1:-}"
  require_cmd kubectl
  require_cmd helm
  validate_inputs

  case "$action" in
    apply)
      apply_metrics_server
      ;;
    check)
      check_metrics_server
      ;;
    delete)
      delete_metrics_server
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
