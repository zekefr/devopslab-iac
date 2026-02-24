#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

TERRAFORM_DIR="${TERRAFORM_DIR:-${REPO_ROOT}/terraform/environments/lab}"
OUTPUT_FILE="${TALOS_CLUSTER_GENERATED_FILE:-${REPO_ROOT}/talos/cluster.generated.env}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

main() {
  require_cmd terraform

  if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo "Missing Terraform directory: $TERRAFORM_DIR" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$OUTPUT_FILE")"

  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "${tmp_file:-}"' EXIT

  if ! terraform -chdir="$TERRAFORM_DIR" output -raw talos_cluster_env >"$tmp_file"; then
    echo "Failed to read Terraform output 'talos_cluster_env'." >&2
    echo "Run: make tf-init && make tf-apply (state must include latest outputs)." >&2
    exit 1
  fi

  if ! grep -q '^CLUSTER_NAME=' "$tmp_file"; then
    echo "Generated cluster env is missing CLUSTER_NAME. Output seems invalid." >&2
    exit 1
  fi

  mv "$tmp_file" "$OUTPUT_FILE"
  chmod 600 "$OUTPUT_FILE"

  echo "Wrote Talos generated config: $OUTPUT_FILE"
}

main "$@"
