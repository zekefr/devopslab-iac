#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CONFIG_FILE="${TALOS_CLUSTER_FILE:-${REPO_ROOT}/talos/cluster.generated.env}"
LOCAL_CONFIG_FILE="${TALOS_CLUSTER_LOCAL_FILE:-${REPO_ROOT}/talos/cluster.local.env}"
OUTPUT_DIR="${TALOS_OUTPUT_DIR:-${REPO_ROOT}/talos/generated}"
TALOS_CLIENT_CONFIG="${TALOS_CLIENT_CONFIG:-${OUTPUT_DIR}/base/talosconfig}"
TALOS_SECRETS_FILE="${TALOS_SECRETS_FILE:-${OUTPUT_DIR}/base/secrets.yaml}"
NODE_HOSTNAME_PREFIX="${NODE_HOSTNAME_PREFIX:-talos}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <generate|apply|bootstrap|all>

Environment overrides:
  TALOS_CLUSTER_FILE        Path to generated cluster config file (default: talos/cluster.generated.env)
  TALOS_CLUSTER_LOCAL_FILE  Path to optional local override file (default: talos/cluster.local.env)
  TALOS_OUTPUT_DIR     Output directory for generated files (default: talos/generated)
  TALOS_CLIENT_CONFIG  Path to talosconfig used for bootstrap (default: talos/generated/base/talosconfig)
  TALOS_SECRETS_FILE   Path to Talos secrets bundle (default: talos/generated/base/secrets.yaml)
  NODE_HOSTNAME_PREFIX Hostname prefix for nodes (default: talos)
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

  : "${CLUSTER_NAME:?CLUSTER_NAME is required in $CONFIG_FILE}"
  : "${CLUSTER_ENDPOINT:?CLUSTER_ENDPOINT is required in $CONFIG_FILE}"
  : "${GATEWAY_IPV4:?GATEWAY_IPV4 is required in $CONFIG_FILE}"

  if [[ ! "$(declare -p CONTROL_PLANE_NODES 2>/dev/null || true)" =~ ^declare\ -a ]]; then
    echo "CONTROL_PLANE_NODES must be a bash array in $CONFIG_FILE" >&2
    exit 1
  fi
  if [[ ! "$(declare -p WORKER_NODES 2>/dev/null || true)" =~ ^declare\ -a ]]; then
    echo "WORKER_NODES must be a bash array in $CONFIG_FILE" >&2
    exit 1
  fi
  if [[ ! "$(declare -p DNS_SERVERS 2>/dev/null || true)" =~ ^declare\ -a ]]; then
    echo "DNS_SERVERS must be a bash array in $CONFIG_FILE" >&2
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
  if ((${#WORKER_NODES[@]} == 0)); then
    echo "WORKER_NODES cannot be empty in $CONFIG_FILE" >&2
    exit 1
  fi
  if ((${#DNS_SERVERS[@]} == 0)); then
    echo "DNS_SERVERS cannot be empty in $CONFIG_FILE" >&2
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

all_nodes() {
  printf "%s\n" "${CONTROL_PLANE_NODES[@]}" "${WORKER_NODES[@]}"
}

has_node_target_ip() {
  local node="$1"
  local key
  for key in "${!NODE_TARGET_IP[@]}"; do
    if [[ "$key" == "$node" ]]; then
      return 0
    fi
  done
  return 1
}

get_node_target_ip() {
  local node="$1"
  local key
  for key in "${!NODE_TARGET_IP[@]}"; do
    if [[ "$key" == "$node" ]]; then
      printf "%s" "${NODE_TARGET_IP["$key"]}"
      return 0
    fi
  done
  return 1
}

is_control_plane() {
  local node="$1"
  local cp
  for cp in "${CONTROL_PLANE_NODES[@]}"; do
    if [[ "$cp" == "$node" ]]; then
      return 0
    fi
  done
  return 1
}

write_patch_file() {
  local node="$1"
  local ip="$2"
  local patch_file="$3"

  mkdir -p "$(dirname "$patch_file")"

  {
    cat <<EOF
machine:
  network:
    interfaces:
      - deviceSelector:
          physical: true
        dhcp: false
        addresses:
          - ${ip}/24
        routes:
          - network: 0.0.0.0/0
            gateway: ${GATEWAY_IPV4}
    nameservers:
EOF
    local dns
    for dns in "${DNS_SERVERS[@]}"; do
      printf "      - %s\n" "$dns"
    done
  } >"$patch_file"
}

strip_hostname_config_doc() {
  local file="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  awk '
    function flush_doc(    i,is_hostname_config) {
      if (doc_len == 0) {
        return
      }

      is_hostname_config = 0
      for (i = 1; i <= doc_len; i++) {
        if (docs[i] ~ /^kind:[[:space:]]*HostnameConfig([[:space:]]*#.*)?$/) {
          is_hostname_config = 1
          break
        }
      }

      if (!is_hostname_config) {
        if (printed_any) {
          print "---"
        }
        for (i = 1; i <= doc_len; i++) {
          print docs[i]
        }
        printed_any = 1
      }

      delete docs
      doc_len = 0
    }

    /^---[[:space:]]*$/ {
      flush_doc()
      next
    }

    {
      docs[++doc_len] = $0
    }

    END {
      flush_doc()
    }
  ' "$file" >"$tmp_file"

  mv "$tmp_file" "$file"
}

append_hostname_config_doc() {
  local file="$1"
  local node="$2"
  local hostname="${NODE_HOSTNAME_PREFIX}-${node}"

  cat >>"$file" <<EOF
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: ${hostname}
EOF
}

require_talosconfig() {
  if [[ ! -s "$TALOS_CLIENT_CONFIG" ]]; then
    echo "Missing or empty talosconfig: $TALOS_CLIENT_CONFIG" >&2
    echo "Run: make talos-generate" >&2
    exit 1
  fi
}

generate_configs() {
  require_cmd talosctl

  mkdir -p "$OUTPUT_DIR/base" "$OUTPUT_DIR/patches" "$OUTPUT_DIR/rendered"

  if [[ ! -s "$TALOS_SECRETS_FILE" ]]; then
    echo "Generating Talos secrets bundle: $TALOS_SECRETS_FILE"
    talosctl gen secrets --output-file "$TALOS_SECRETS_FILE"
  else
    echo "Reusing Talos secrets bundle: $TALOS_SECRETS_FILE"
  fi

  talosctl gen config "$CLUSTER_NAME" "https://${CLUSTER_ENDPOINT}:6443" --with-secrets "$TALOS_SECRETS_FILE" --output-dir "$OUTPUT_DIR/base" --force

  local node ip patch_file base_file rendered_file
  while IFS= read -r node; do
    if [[ -z "$node" ]]; then
      continue
    fi

    if ! has_node_target_ip "$node"; then
      echo "Missing NODE_TARGET_IP for node '$node'" >&2
      exit 1
    fi
    ip="$(get_node_target_ip "$node")"

    patch_file="$OUTPUT_DIR/patches/${node}.yaml"
    write_patch_file "$node" "$ip" "$patch_file"

    if is_control_plane "$node"; then
      base_file="$OUTPUT_DIR/base/controlplane.yaml"
    else
      base_file="$OUTPUT_DIR/base/worker.yaml"
    fi

    rendered_file="$OUTPUT_DIR/rendered/${node}.yaml"
    talosctl machineconfig patch "$base_file" --patch "@${patch_file}" --output "$rendered_file"
    # With static node networking, HostnameConfig(auto: stable) conflicts at apply time.
    strip_hostname_config_doc "$rendered_file"
    append_hostname_config_doc "$rendered_file" "$node"
    echo "Rendered config: $rendered_file"
  done < <(all_nodes)
}

configure_talos_client_context() {
  local -a endpoint_ips=()
  local -a node_ips=()
  local node ip

  for node in "${CONTROL_PLANE_NODES[@]}"; do
    if ! has_node_target_ip "$node"; then
      echo "Missing NODE_TARGET_IP for control-plane node '$node'" >&2
      exit 1
    fi
    endpoint_ips+=("$(get_node_target_ip "$node")")
  done

  while IFS= read -r node; do
    if [[ -z "$node" ]]; then
      continue
    fi
    if ! has_node_target_ip "$node"; then
      echo "Missing NODE_TARGET_IP for node '$node'" >&2
      exit 1
    fi
    ip="$(get_node_target_ip "$node")"
    node_ips+=("$ip")
  done < <(all_nodes)

  talosctl --talosconfig "$TALOS_CLIENT_CONFIG" config endpoint "${endpoint_ips[@]}"
  talosctl --talosconfig "$TALOS_CLIENT_CONFIG" config node "${node_ips[@]}"
}

apply_configs() {
  require_cmd talosctl

  local node endpoint rendered_file insecure_output secure_node context_configured
  context_configured=0
  while IFS= read -r node; do
    if [[ -z "$node" ]]; then
      continue
    fi

    rendered_file="$OUTPUT_DIR/rendered/${node}.yaml"
    if [[ ! -f "$rendered_file" ]]; then
      echo "Missing rendered config: $rendered_file (run generate first)" >&2
      exit 1
    fi

    if ! has_node_target_ip "$node"; then
      echo "Missing NODE_TARGET_IP for node '$node'" >&2
      exit 1
    fi

    endpoint="$(get_node_target_ip "$node")"
    echo "Applying ${rendered_file} to node endpoint ${endpoint}"
    if ! insecure_output="$(talosctl apply-config --insecure --nodes "$endpoint" --file "$rendered_file" 2>&1)"; then
      if [[ "$insecure_output" == *"tls: certificate required"* ]]; then
        require_talosconfig
        if ((context_configured == 0)); then
          configure_talos_client_context
          context_configured=1
        fi

        if ! has_node_target_ip "$node"; then
          echo "Missing NODE_TARGET_IP for node '$node'" >&2
          exit 1
        fi

        secure_node="$(get_node_target_ip "$node")"
        echo "Node ${node} requires authenticated Talos API, retrying via ${secure_node}"
        talosctl --talosconfig "$TALOS_CLIENT_CONFIG" apply-config --nodes "$secure_node" --file "$rendered_file"
      else
        echo "$insecure_output" >&2
        exit 1
      fi
    fi
  done < <(all_nodes)
}

bootstrap_cluster() {
  require_cmd talosctl
  require_talosconfig
  configure_talos_client_context

  local bootstrap_node
  if [[ -n "${BOOTSTRAP_NODE:-}" ]]; then
    bootstrap_node="$BOOTSTRAP_NODE"
  else
    bootstrap_node="${CONTROL_PLANE_NODES[0]}"
  fi

  if ! has_node_target_ip "$bootstrap_node"; then
    echo "BOOTSTRAP_NODE '$bootstrap_node' is missing in NODE_TARGET_IP" >&2
    exit 1
  fi

  local bootstrap_ip
  bootstrap_ip="$(get_node_target_ip "$bootstrap_node")"

  local bootstrap_output
  echo "Bootstrapping cluster via ${bootstrap_node} (${bootstrap_ip}) using talosconfig ${TALOS_CLIENT_CONFIG}"
  if ! bootstrap_output="$(talosctl --talosconfig "$TALOS_CLIENT_CONFIG" bootstrap --nodes "$bootstrap_ip" --endpoints "$CLUSTER_ENDPOINT" 2>&1)"; then
    if [[ "$bootstrap_output" == *"AlreadyExists"* && "$bootstrap_output" == *"etcd data directory is not empty"* ]]; then
      echo "Bootstrap already done on ${bootstrap_node}; continuing."
    else
      echo "$bootstrap_output" >&2
      exit 1
    fi
  fi
  talosctl --talosconfig "$TALOS_CLIENT_CONFIG" kubeconfig --force --nodes "$bootstrap_ip" --endpoints "$CLUSTER_ENDPOINT"

  if command -v kubectl >/dev/null 2>&1; then
    local attempt max_attempts
    max_attempts=30
    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
      if kubectl --request-timeout=5s get --raw=/readyz >/dev/null 2>&1; then
        kubectl get nodes -o wide
        return
      fi
      echo "Kubernetes API not ready yet (${attempt}/${max_attempts}), retrying in 5s..."
      sleep 5
    done
    echo "Kubernetes API is still not ready. Retry: kubectl get nodes -o wide" >&2
  fi
}

main() {
  local action="${1:-}"
  case "$action" in
    generate)
      load_config generate_configs
      ;;
    apply)
      load_config apply_configs
      ;;
    bootstrap)
      load_config bootstrap_cluster
      ;;
    all)
      load_config all_actions
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

all_actions() {
  generate_configs
  apply_configs
  bootstrap_cluster
}

main "$@"
