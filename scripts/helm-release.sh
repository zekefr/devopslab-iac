#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <apply|check|delete> [release-dir]

Arguments:
  release-dir                Path to release directory (optional if HELM_RELEASE_DIR is set)

Environment:
  HELM_RELEASE_DIR           Release directory containing release.env and values file
  HELM_VALUES_FILE           Values file path override (default: <release-dir>/values.lab.yaml)
  HELM_WAIT_TIMEOUT          Helm wait timeout (default: 180s)

Expected release.env variables:
  HELM_REPO_NAME
  HELM_REPO_URL
  HELM_CHART_NAME
  HELM_CHART_VERSION
  HELM_RELEASE_NAME
  HELM_RELEASE_NAMESPACE
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

resolve_release_dir() {
  local arg_dir="${1:-}"
  if [[ -n "${HELM_RELEASE_DIR:-}" ]]; then
    printf "%s" "$HELM_RELEASE_DIR"
    return 0
  fi
  if [[ -n "$arg_dir" ]]; then
    printf "%s" "$arg_dir"
    return 0
  fi
  return 1
}

load_release_config() {
  local release_dir="$1"
  local release_file="${release_dir}/release.env"

  if [[ ! -f "$release_file" ]]; then
    echo "Missing release config: $release_file" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$release_file"

  : "${HELM_REPO_NAME:?HELM_REPO_NAME is required in ${release_file}}"
  : "${HELM_REPO_URL:?HELM_REPO_URL is required in ${release_file}}"
  : "${HELM_CHART_NAME:?HELM_CHART_NAME is required in ${release_file}}"
  : "${HELM_CHART_VERSION:?HELM_CHART_VERSION is required in ${release_file}}"
  : "${HELM_RELEASE_NAME:?HELM_RELEASE_NAME is required in ${release_file}}"
  : "${HELM_RELEASE_NAMESPACE:?HELM_RELEASE_NAMESPACE is required in ${release_file}}"

  HELM_VALUES_FILE="${HELM_VALUES_FILE:-${release_dir}/values.lab.yaml}"
  HELM_WAIT_TIMEOUT="${HELM_WAIT_TIMEOUT:-180s}"

  if [[ ! -f "$HELM_VALUES_FILE" ]]; then
    echo "Missing values file: $HELM_VALUES_FILE" >&2
    exit 1
  fi
}

ensure_helm_repo() {
  if ! helm repo list | awk '{print $1}' | grep -q "^${HELM_REPO_NAME}$"; then
    helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
  fi
  helm repo update "$HELM_REPO_NAME"
}

apply_release() {
  ensure_helm_repo
  helm upgrade --install "$HELM_RELEASE_NAME" "$HELM_CHART_NAME" \
    --namespace "$HELM_RELEASE_NAMESPACE" \
    --create-namespace \
    --values "$HELM_VALUES_FILE" \
    --version "$HELM_CHART_VERSION" \
    --wait \
    --timeout "$HELM_WAIT_TIMEOUT"
}

check_release() {
  helm -n "$HELM_RELEASE_NAMESPACE" status "$HELM_RELEASE_NAME"
}

delete_release() {
  if helm -n "$HELM_RELEASE_NAMESPACE" status "$HELM_RELEASE_NAME" >/dev/null 2>&1; then
    helm uninstall "$HELM_RELEASE_NAME" --namespace "$HELM_RELEASE_NAMESPACE"
  else
    echo "No Helm release found: ${HELM_RELEASE_NAME} in namespace ${HELM_RELEASE_NAMESPACE}"
  fi
}

main() {
  local action="${1:-}"
  local release_dir_arg="${2:-}"
  local release_dir

  require_cmd helm

  if ! release_dir="$(resolve_release_dir "$release_dir_arg")"; then
    usage
    exit 1
  fi

  # Resolve relative paths from repository root for consistency.
  if [[ "$release_dir" != /* ]]; then
    release_dir="${REPO_ROOT}/${release_dir}"
  fi

  load_release_config "$release_dir"

  case "$action" in
    apply)
      apply_release
      ;;
    check)
      check_release
      ;;
    delete)
      delete_release
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
