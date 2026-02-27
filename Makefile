.DEFAULT_GOAL := help

ANSIBLE_DIR=ansible
TERRAFORM_LAB_DIR=terraform/environments/lab
TALOS_BOOTSTRAP_SCRIPT=scripts/talos-bootstrap.sh
TALOS_SYNC_SCRIPT=scripts/talos-sync-from-terraform.sh
TALOS_POST_BOOTSTRAP_SCRIPT=scripts/talos-post-bootstrap.sh
KUBE_VIP_SCRIPT=scripts/kube-vip.sh
METRICS_SERVER_SCRIPT=scripts/metrics-server.sh
METALLB_SCRIPT=scripts/metallb.sh
HELM_RELEASE_SCRIPT=scripts/helm-release.sh

.PHONY: help doctor status list-releases pre-commit-install lint tf-init tf-validate tf-plan tf-apply tf-apply-auto tf-apply-replace talos-sync talos-generate talos-apply talos-bootstrap talos-post-bootstrap talos-all helm-apply helm-check helm-delete kube-vip-apply kube-vip-check kube-vip-recover kube-vip-delete metrics-server-apply metrics-server-check metrics-server-delete metallb-apply metallb-check metallb-delete ansible-proxmox-bootstrap ansible-proxmox-upgrade ansible-proxmox-tweaks ansible-proxmox-tuning ansible-proxmox-hardening

help: ## Show available make targets and usage examples
	@echo "Usage: make <target>"
	@echo
	@echo "Examples:"
	@echo "  make tf-plan"
	@echo "  make doctor"
	@echo "  make status"
	@echo "  make metrics-server-apply"
	@echo "  make metallb-apply"
	@echo "  make tf-apply-replace REPLACE='module.talos_proxmox_cluster.proxmox_virtual_environment_vm.k8s_node[\"cpk8s01\"]'"
	@echo "  make helm-apply RELEASE='kube-vip'"
	@echo
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-26s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

doctor: ## Run local environment diagnostics (toolchain, auth env, kubectl access)
	@set -eu; \
	if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then \
		C_RESET='\033[0m'; \
		C_BOLD='\033[1m'; \
		C_GREEN='\033[32m'; \
		C_YELLOW='\033[33m'; \
		C_RED='\033[31m'; \
		C_CYAN='\033[36m'; \
	else \
		C_RESET=''; \
		C_BOLD=''; \
		C_GREEN=''; \
		C_YELLOW=''; \
		C_RED=''; \
		C_CYAN=''; \
	fi; \
	fail=0; \
	print_section() { printf "%b== %s ==%b\n" "$$C_CYAN$$C_BOLD" "$$1" "$$C_RESET"; }; \
	print_ok() { printf "%b[ok]%b %s\n" "$$C_GREEN$$C_BOLD" "$$C_RESET" "$$1"; }; \
	print_warn() { printf "%b[warn]%b %s\n" "$$C_YELLOW$$C_BOLD" "$$C_RESET" "$$1"; }; \
	print_fail() { printf "%b[fail]%b %s\n" "$$C_RED$$C_BOLD" "$$C_RESET" "$$1"; }; \
	check_bin() { \
		if command -v "$$1" >/dev/null 2>&1; then \
			print_ok "binary: $$1"; \
		else \
			print_fail "missing binary: $$1"; \
			fail=1; \
		fi; \
	}; \
	print_section "Binaries"; \
	check_bin uv; \
	check_bin mise; \
	check_bin direnv; \
	echo; \
	print_section "Runtime versions"; \
	uv run python --version || fail=1; \
	uv run ansible-lint --version >/dev/null || fail=1; \
	mise exec -- terraform version | head -n1 || fail=1; \
	mise exec -- talosctl version --client >/dev/null || fail=1; \
	mise exec -- kubectl version --client >/dev/null || fail=1; \
	mise exec -- helm version --short >/dev/null || fail=1; \
	print_ok "uv/mise managed toolchain available"; \
	echo; \
	print_section "Terraform auth env (direnv)"; \
	if direnv exec $(TERRAFORM_LAB_DIR) bash -lc '[[ -n "$$PROXMOX_VE_ENDPOINT" ]]'; then \
		print_ok "PROXMOX_VE_ENDPOINT set"; \
	else \
		print_fail "PROXMOX_VE_ENDPOINT missing"; \
		fail=1; \
	fi; \
	if direnv exec $(TERRAFORM_LAB_DIR) bash -lc '[[ -n "$$PROXMOX_VE_API_TOKEN" ]]'; then \
		print_ok "PROXMOX_VE_API_TOKEN set"; \
	else \
		print_fail "PROXMOX_VE_API_TOKEN missing"; \
		fail=1; \
	fi; \
	echo; \
	print_section "Kubernetes access"; \
	if kubectl --request-timeout=5s get --raw=/readyz >/dev/null 2>&1; then \
		print_ok "kubectl can reach API (/readyz)"; \
	else \
		print_warn "kubectl cannot reach API right now"; \
	fi; \
	echo; \
	if [ "$$fail" -ne 0 ]; then \
		printf "%bDoctor checks failed.%b\n" "$$C_RED$$C_BOLD" "$$C_RESET"; \
		exit "$$fail"; \
	fi; \
	printf "%bDoctor checks passed.%b\n" "$$C_GREEN$$C_BOLD" "$$C_RESET"

status: ## Show lab status summary (Terraform state, Kubernetes nodes, Helm releases)
	@set -eu; \
	if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then \
		C_RESET='\033[0m'; \
		C_BOLD='\033[1m'; \
		C_GREEN='\033[32m'; \
		C_YELLOW='\033[33m'; \
		C_CYAN='\033[36m'; \
	else \
		C_RESET=''; \
		C_BOLD=''; \
		C_GREEN=''; \
		C_YELLOW=''; \
		C_CYAN=''; \
	fi; \
	print_section() { printf "%b== %s ==%b\n" "$$C_CYAN$$C_BOLD" "$$1" "$$C_RESET"; }; \
	print_ok() { printf "%b[ok]%b %s\n" "$$C_GREEN$$C_BOLD" "$$C_RESET" "$$1"; }; \
	print_warn() { printf "%b[warn]%b %s\n" "$$C_YELLOW$$C_BOLD" "$$C_RESET" "$$1"; }; \
	print_info() { printf "%s\n" "$$1"; }; \
	echo "Lab status snapshot"; \
	echo; \
	print_section "Terraform"; \
	if tf_state=$$(DIRENV_LOG_FORMAT= direnv exec $(TERRAFORM_LAB_DIR) terraform -chdir=$(TERRAFORM_LAB_DIR) state list 2>/dev/null); then \
		tf_count=$$(printf "%s\n" "$$tf_state" | sed '/^$$/d' | wc -l | tr -d ' '); \
		print_ok "state resources: $$tf_count"; \
	else \
		print_warn "terraform state unavailable (run make tf-init or check backend access)"; \
	fi; \
	echo; \
	print_section "Kubernetes"; \
	if ctx=$$(mise exec -- kubectl config current-context 2>/dev/null); then \
		print_info "context: $$ctx"; \
	else \
		print_warn "kubectl context not configured"; \
	fi; \
	if server=$$(mise exec -- kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null); then \
		if [ -n "$$server" ]; then \
			print_info "api-server: $$server"; \
		fi; \
	fi; \
	if mise exec -- kubectl --request-timeout=5s get --raw=/readyz >/dev/null 2>&1; then \
		print_ok "API reachable"; \
		if nodes=$$(mise exec -- kubectl get nodes --no-headers 2>/dev/null); then \
			node_count=$$(printf "%s\n" "$$nodes" | sed '/^$$/d' | wc -l | tr -d ' '); \
			ready_count=$$(printf "%s\n" "$$nodes" | awk 'index($$2,"Ready")==1 {c++} END {print c+0}'); \
			print_info "nodes ready: $$ready_count/$$node_count"; \
		fi; \
		if mise exec -- kubectl get --raw '/apis/metrics.k8s.io/v1beta1/nodes' >/dev/null 2>&1; then \
			print_ok "metrics API reachable"; \
		else \
			print_warn "metrics API not reachable (metrics-server missing or not ready)"; \
		fi; \
		if lb_services=$$(mise exec -- kubectl get svc -A --field-selector spec.type=LoadBalancer --no-headers 2>/dev/null); then \
			lb_count=$$(printf "%s\n" "$$lb_services" | sed '/^$$/d' | wc -l | tr -d ' '); \
			if [ "$$lb_count" -gt 0 ]; then \
				print_info "loadbalancer services: $$lb_count"; \
			else \
				print_info "loadbalancer services: 0"; \
			fi; \
		fi; \
		mise exec -- kubectl get nodes -o wide; \
	else \
		print_warn "API not reachable right now"; \
	fi; \
	echo; \
	print_section "Helm"; \
	if releases=$$(mise exec -- helm list -A 2>/dev/null); then \
		release_count=$$(printf "%s\n" "$$releases" | awk 'NR>1 {c++} END {print c+0}'); \
		print_info "releases: $$release_count"; \
		printf "%s\n" "$$releases"; \
	else \
		print_warn "helm list unavailable"; \
	fi

list-releases: ## List available Helm release directories under kubernetes/helm
	@if [ -d kubernetes/helm ]; then \
		find kubernetes/helm -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort; \
	else \
		echo "No kubernetes/helm directory found."; \
	fi

pre-commit-install: ## Install pre-commit hooks
	uv run pre-commit install

lint: ## Run full repository lint suite
	uv run pre-commit run --all-files

tf-init: ## Initialize Terraform lab environment
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-init

tf-validate: ## Validate Terraform lab configuration
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-validate

tf-plan: ## Show Terraform lab execution plan
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-plan

tf-apply: ## Apply Terraform lab changes (interactive approval)
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-apply

tf-apply-auto: ## Apply Terraform lab changes without approval prompt
	direnv exec $(TERRAFORM_LAB_DIR) mise run tf-apply-auto

tf-apply-replace: ## Force Terraform replacement for one or more resources via REPLACE
	@if [ -z "$(REPLACE)" ]; then \
		echo "Usage: make tf-apply-replace REPLACE='<resource1> <resource2> ...'"; \
		echo "Example: make tf-apply-replace REPLACE='proxmox_virtual_environment_vm.k8s_node[\"cpk8s01\"]'"; \
		exit 1; \
	fi
	@echo "Destructive operation: Terraform will recreate the following resources:"
	@for target in $(REPLACE); do \
		canonical_target=$$(printf '%s' "$$target" | sed -E 's/\[([[:alnum:]_-]+)\]/["\1"]/g'); \
		echo "  - $$canonical_target"; \
	done
	@set -eu; \
	set --; \
	for target in $(REPLACE); do \
		canonical_target=$$(printf '%s' "$$target" | sed -E 's/\[([[:alnum:]_-]+)\]/["\1"]/g'); \
		set -- "$$@" "-replace=$$canonical_target"; \
	done; \
	direnv exec $(TERRAFORM_LAB_DIR) terraform -chdir=$(TERRAFORM_LAB_DIR) apply "$$@"

talos-sync: ## Generate talos/cluster.generated.env from Terraform outputs
	mise exec -- $(TALOS_SYNC_SCRIPT)

talos-generate: talos-sync ## Generate Talos machine configs
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) generate

talos-apply: ## Apply rendered Talos configs to nodes
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) apply

talos-bootstrap: ## Bootstrap Talos cluster and refresh kubeconfig
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) bootstrap

talos-post-bootstrap: ## Run post-bootstrap health checks (etcd, nodes, kube-system)
	mise exec -- $(TALOS_POST_BOOTSTRAP_SCRIPT) check

talos-all: ## Run full Talos flow: generate, apply, bootstrap
	mise exec -- $(TALOS_BOOTSTRAP_SCRIPT) all

helm-apply: ## Apply Helm release from kubernetes/helm/<release> via RELEASE
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-apply RELEASE='<release-name>'"; \
		echo "Example: make helm-apply RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) apply

helm-check: ## Check Helm release status via RELEASE
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-check RELEASE='<release-name>'"; \
		echo "Example: make helm-check RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) check

helm-delete: ## Delete Helm release via RELEASE
	@if [ -z "$(RELEASE)" ]; then \
		echo "Usage: make helm-delete RELEASE='<release-name>'"; \
		echo "Example: make helm-delete RELEASE='kube-vip'"; \
		exit 1; \
	fi
	HELM_RELEASE_DIR=kubernetes/helm/$(RELEASE) mise exec -- $(HELM_RELEASE_SCRIPT) delete

kube-vip-apply: ## Apply kube-vip Helm release
	mise exec -- $(KUBE_VIP_SCRIPT) apply

kube-vip-check: ## Check kube-vip rollout and VIP API readiness
	mise exec -- $(KUBE_VIP_SCRIPT) check

kube-vip-recover: ## Recover kube-vip availability (restart kube-proxy + kube-vip)
	mise exec -- $(KUBE_VIP_SCRIPT) recover

kube-vip-delete: ## Delete kube-vip Helm release
	mise exec -- $(KUBE_VIP_SCRIPT) delete

metrics-server-apply: ## Apply metrics-server Helm release
	mise exec -- $(METRICS_SERVER_SCRIPT) apply

metrics-server-check: ## Check metrics-server rollout and metrics API status
	mise exec -- $(METRICS_SERVER_SCRIPT) check

metrics-server-delete: ## Delete metrics-server Helm release
	mise exec -- $(METRICS_SERVER_SCRIPT) delete

metallb-apply: ## Apply MetalLB Helm release and address pool manifests
	mise exec -- $(METALLB_SCRIPT) apply

metallb-check: ## Check MetalLB rollout and address pool configuration
	mise exec -- $(METALLB_SCRIPT) check

metallb-delete: ## Delete MetalLB address pool manifests and Helm release
	mise exec -- $(METALLB_SCRIPT) delete

ansible-proxmox-bootstrap: ## Run Ansible Proxmox bootstrap tasks
	@echo "Bootstrapping Proxmox host"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'bootstrap'

ansible-proxmox-upgrade: ## Run Ansible Proxmox upgrade tasks
	@echo "Upgrading Proxmox host"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'upgrade'

ansible-proxmox-tweaks: ## Run Ansible Proxmox tweaks tasks
	@echo "Applying Proxmox tweaks"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'tweaks'

ansible-proxmox-tuning: ## Run Ansible Proxmox tuning tasks
	@echo "Applying Proxmox tuning"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'tuning'

ansible-proxmox-hardening: ## Run Ansible Proxmox hardening tasks
	@echo "Applying Proxmox hardening"
	cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/proxmox.yml -t 'hardening'
