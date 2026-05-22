# ============================================================================
# NT548 Task Manager — DevOps Automation (v3.1 — verbose logging)
# ============================================================================
# Triết lý: 2 lệnh chính
#   make deploy   — từ zero đến full system chạy (~35 phút)
#   make destroy  — xóa sạch mọi resource
#
# Đọc log: mỗi dòng có symbol cho biết bạn đang ở đâu:
#   ▶ = đang bắt đầu      ✓ = thành công        ✗ = thất bại
#   ⚠ = warning           ℹ = thông tin         → = chi tiết phụ
#
# Lệnh quan sát:
#   make hibernate / make wake — tắt/bật để tiết kiệm chi phí
#   make status                — check trạng thái hiện tại
#   make verify                — verify mọi thứ chạy
# ============================================================================

# ─── Colors ────────────────────────────────────────────────────────────────
COLOR_RESET   := \033[0m
COLOR_GREEN   := \033[32m
COLOR_YELLOW  := \033[33m
COLOR_RED     := \033[31m
COLOR_BLUE    := \033[34m
COLOR_CYAN    := \033[36m
COLOR_GRAY    := \033[90m
COLOR_BOLD    := \033[1m

# ─── Project config ────────────────────────────────────────────────────────
PROJECT       := devops
ENVIRONMENT   := dev
REGION        := ap-southeast-1
NAMESPACE     := task-manager-dev
CLUSTER_NAME  := $(PROJECT)-$(ENVIRONMENT)

# ─── Paths ─────────────────────────────────────────────────────────────────
INFRA_DIR      := infrastructure
ENVS_DIR       := $(INFRA_DIR)/envs

# Config repo — chứa Helm chart + ArgoCD app definitions
# ⚠️ Set CONFIG_REPO env var nếu repo không ở $HOME/nt548-config
CONFIG_REPO    ?= $(HOME)/nt548-config

# ArgoCD
ARGOCD_NAMESPACE := argocd
ARGOCD_VERSION   := stable

# ============================================================================
# HELP — Mặc định
# ============================================================================
.PHONY: help
help:  ## Hiển thị help
	@echo ""
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)║  NT548 Task Manager — DevOps Automation      ║$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)🚀 Lệnh chính:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)make deploy$(COLOR_RESET)              Deploy mọi thứ từ zero (~35 phút)"
	@echo "  $(COLOR_GREEN)make destroy$(COLOR_RESET)             Xóa sạch mọi resource (~30 phút)"
	@echo ""
	@echo "$(COLOR_BOLD)💰 Cost saving:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)make hibernate$(COLOR_RESET)           Tắt compute, giữ data (~70% tiết kiệm)"
	@echo "  $(COLOR_GREEN)make wake$(COLOR_RESET)                Bật lại hệ thống"
	@echo "  $(COLOR_GREEN)make wake-dns$(COLOR_RESET)            Update DNS sau wake (ALB mới)"
	@echo ""
	@echo "$(COLOR_BOLD)🔍 Quan sát:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)make status$(COLOR_RESET)              Check trạng thái resources"
	@echo "  $(COLOR_GREEN)make verify$(COLOR_RESET)              Verify end-to-end"
	@echo "  $(COLOR_GREEN)make logs-backend$(COLOR_RESET)        Tail backend logs"
	@echo "  $(COLOR_GREEN)make argocd-ui$(COLOR_RESET)           Port-forward ArgoCD UI"
	@echo ""
	@echo "$(COLOR_BOLD)⚙️  Setup (chỉ làm 1 lần):$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)make preflight$(COLOR_RESET)           Check tools + credentials"
	@echo "  $(COLOR_GREEN)make bootstrap$(COLOR_RESET)           Tạo S3 + DynamoDB cho TF state"
	@echo ""
	@echo "$(COLOR_GRAY)Tất cả target:$(COLOR_RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-25s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""

# ============================================================================
# PREFLIGHT CHECK — Verify môi trường trước khi deploy
# ============================================================================
.PHONY: preflight
preflight:  ## Check tools, AWS credentials, config repo
	@echo ""
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)  Preflight Checks$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)▶ Checking required tools...$(COLOR_RESET)"
	@command -v aws >/dev/null 2>&1 || { echo "$(COLOR_RED)  ✗ aws cli NOT found$(COLOR_RESET)"; exit 1; }
	@echo "  → aws cli: $$(aws --version 2>&1 | head -1)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(COLOR_RED)  ✗ terraform NOT found$(COLOR_RESET)"; exit 1; }
	@echo "  → terraform: $$(terraform version | head -1)"
	@command -v kubectl >/dev/null 2>&1 || { echo "$(COLOR_RED)  ✗ kubectl NOT found$(COLOR_RESET)"; exit 1; }
	@echo "  → kubectl: $$(kubectl version --client 2>&1 | grep -i 'client version' | head -1)"
	@command -v yq >/dev/null 2>&1 || { \
	  echo "$(COLOR_RED)  ✗ yq NOT found. Install:$(COLOR_RESET)"; \
	  echo "$(COLOR_YELLOW)    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64$(COLOR_RESET)"; \
	  echo "$(COLOR_YELLOW)    sudo chmod +x /usr/local/bin/yq$(COLOR_RESET)"; \
	  exit 1; }
	@echo "  → yq: $$(yq --version)"
	@echo "$(COLOR_GREEN)  ✓ All tools available$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Checking AWS credentials...$(COLOR_RESET)"
	@aws sts get-caller-identity >/dev/null 2>&1 || { \
	  echo "$(COLOR_RED)  ✗ AWS credentials invalid or expired$(COLOR_RESET)"; \
	  echo "$(COLOR_YELLOW)    Run: aws configure$(COLOR_RESET)"; \
	  exit 1; }
	@echo "  → Account: $$(aws sts get-caller-identity --query Account --output text)"
	@echo "  → User:    $$(aws sts get-caller-identity --query Arn --output text)"
	@echo "  → Region:  $(REGION)"
	@echo "$(COLOR_GREEN)  ✓ AWS credentials valid$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Checking config repo...$(COLOR_RESET)"
	@[ -d "$(CONFIG_REPO)" ] || { \
	  echo "$(COLOR_RED)  ✗ Config repo NOT found at $(CONFIG_REPO)$(COLOR_RESET)"; \
	  echo "$(COLOR_YELLOW)    Either clone the config repo to $(HOME)/nt548-config$(COLOR_RESET)"; \
	  echo "$(COLOR_YELLOW)    Or: export CONFIG_REPO=/path/to/your/nt548-config$(COLOR_RESET)"; \
	  exit 1; }
	@echo "  → Path: $(CONFIG_REPO)"
	@[ -d "$(CONFIG_REPO)/charts/task-manager" ] || { \
	  echo "$(COLOR_RED)  ✗ Helm chart not found in config repo$(COLOR_RESET)"; \
	  exit 1; }
	@echo "  → Helm chart: ✓"
	@[ -d "$(CONFIG_REPO)/platform/argocd/apps" ] || { \
	  echo "$(COLOR_RED)  ✗ ArgoCD apps not found in config repo$(COLOR_RESET)"; \
	  exit 1; }
	@echo "  → ArgoCD apps: ✓"
	@echo "$(COLOR_GREEN)  ✓ Config repo OK$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Preflight passed — ready to deploy$(COLOR_RESET)"
	@echo ""

# ============================================================================
# BOOTSTRAP — Chỉ chạy 1 lần trong đời project
# ============================================================================
.PHONY: bootstrap
bootstrap:  ## Tạo S3 + DynamoDB cho Terraform state (CHẠY 1 LẦN)
	@echo ""
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)  Bootstrap Terraform Backend$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)  ⚠ Chỉ chạy lệnh này MỘT LẦN duy nhất trong đời project$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)  ⚠ Nó tạo S3 bucket + DynamoDB lock table cho TF state$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Initializing Terraform...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/bootstrap && terraform init
	@echo ""
	@echo "$(COLOR_BLUE)▶ Applying bootstrap resources...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/bootstrap && terraform apply -auto-approve
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Bootstrap complete$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Bạn không cần chạy lệnh 'make bootstrap' nữa.$(COLOR_RESET)"
	@echo ""

.PHONY: setup-symlinks
setup-symlinks:  ## Symlink common.tfvars cho mỗi state
	@for state in dev eks rds secrets dns; do \
	  ln -sf ../../common.tfvars $(ENVS_DIR)/$$state/common.auto.tfvars; \
	done

# ============================================================================
# 🚀 DEPLOY — Lệnh chính, chạy từ zero đến full system
# ============================================================================
.PHONY: deploy
deploy: preflight  ## Deploy full system từ zero (~35 phút)
	@SECONDS=0; \
	echo ""; \
	echo "$(COLOR_BOLD)$(COLOR_BLUE)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"; \
	echo "$(COLOR_BOLD)$(COLOR_BLUE)║   🚀 DEPLOY: zero → full system               ║$(COLOR_RESET)"; \
	echo "$(COLOR_BOLD)$(COLOR_BLUE)║   Estimated time: ~35 minutes                 ║$(COLOR_RESET)"; \
	echo "$(COLOR_BOLD)$(COLOR_BLUE)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"; \
	echo ""; \
	echo "$(COLOR_CYAN)Stages:$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  1. Terraform Infrastructure (~22 min)$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  2. DNS Phase 1: ACM Certificate (~3 min)$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  3. Sync Helm values with TF outputs (~30s)$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  4. ArgoCD + Apps Bootstrap (~10 min)$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  5. Wait ALBs ready (~3 min)$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  6. DNS Phase 2: A records (~1 min)$(COLOR_RESET)"; \
	echo "$(COLOR_CYAN)  7. Verify end-to-end$(COLOR_RESET)"; \
	echo ""; \
# 	$(MAKE) _stage-1-infrastructure || { echo "$(COLOR_RED)✗ Stage 1 failed$(COLOR_RESET)"; exit 1; }; \
# 	$(MAKE) _stage-2-dns-phase1 || { echo "$(COLOR_RED)✗ Stage 2 failed$(COLOR_RESET)"; exit 1; }; \
# 	$(MAKE) _stage-3-sync-helm-values || { echo "$(COLOR_RED)✗ Stage 3 failed$(COLOR_RESET)"; exit 1; }; \
	$(MAKE) _stage-4-argocd || { echo "$(COLOR_RED)✗ Stage 4 failed$(COLOR_RESET)"; exit 1; }; \
	$(MAKE) _stage-5-wait-alb || { echo "$(COLOR_RED)✗ Stage 5 failed$(COLOR_RESET)"; exit 1; }; \
	$(MAKE) _stage-6-dns-phase2 || { echo "$(COLOR_RED)✗ Stage 6 failed$(COLOR_RESET)"; exit 1; }; \
	$(MAKE) _stage-7-verify || { echo "$(COLOR_RED)✗ Stage 7 failed$(COLOR_RESET)"; exit 1; }; \
	DURATION=$$SECONDS; \
	echo ""; \
	echo "$(COLOR_GREEN)$(COLOR_BOLD)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"; \
	echo "$(COLOR_GREEN)$(COLOR_BOLD)║   ✓ DEPLOY COMPLETE in $$(($$DURATION / 60))m $$(($$DURATION % 60))s             ║$(COLOR_RESET)"; \
	echo "$(COLOR_GREEN)$(COLOR_BOLD)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"; \
	echo ""; \
	APP_URL=$$(cd $(ENVS_DIR)/dns && terraform output -raw full_fqdn 2>/dev/null); \
	echo "$(COLOR_CYAN)📍 Access points:$(COLOR_RESET)"; \
	echo "  $(COLOR_GREEN)App:$(COLOR_RESET)      https://$$APP_URL"; \
	echo "  $(COLOR_GREEN)Grafana:$(COLOR_RESET)  https://grafana.vantai.click"; \
	echo "  $(COLOR_GREEN)ArgoCD:$(COLOR_RESET)   make argocd-ui"; \
	echo ""; \
	echo "$(COLOR_CYAN)💡 Useful commands:$(COLOR_RESET)"; \
	echo "  make status        — check resource status"; \
	echo "  make verify        — verify end-to-end"; \
	echo "  make hibernate     — pause to save \$$"; \
	echo ""

# ─── Stage 1: Terraform Infrastructure ─────────────────────────────────────
.PHONY: _stage-1-infrastructure
_stage-1-infrastructure:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 1/7: Terraform Infrastructure (~22 min)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo ""
	@$(MAKE) setup-symlinks
	@echo "$(COLOR_BLUE)▶ [1/5] Initializing all Terraform states...$(COLOR_RESET)"
	@echo "  $(COLOR_GRAY)→ network state$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dev && terraform init -reconfigure \
	  -backend-config=../../backend-config.hcl \
	  -backend-config="key=$(ENVIRONMENT)/network/terraform.tfstate" > /dev/null
	@echo "  $(COLOR_GRAY)→ eks state$(COLOR_RESET)"
	@cd $(ENVS_DIR)/eks && terraform init -reconfigure \
	  -backend-config=../../backend-config.hcl \
	  -backend-config="key=$(ENVIRONMENT)/eks/terraform.tfstate" > /dev/null
	@echo "  $(COLOR_GRAY)→ rds state$(COLOR_RESET)"
	@cd $(ENVS_DIR)/rds && terraform init -reconfigure \
	  -backend-config=../../backend-config.hcl \
	  -backend-config="key=$(ENVIRONMENT)/rds/terraform.tfstate" > /dev/null
	@echo "  $(COLOR_GRAY)→ secrets state$(COLOR_RESET)"
	@cd $(ENVS_DIR)/secrets && terraform init -reconfigure \
	  -backend-config=../../backend-config.hcl \
	  -backend-config="key=$(ENVIRONMENT)/secrets/terraform.tfstate" > /dev/null
	@echo "  $(COLOR_GRAY)→ dns state$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dns && terraform init -reconfigure \
	  -backend-config=../../backend-config.hcl \
	  -backend-config="key=$(ENVIRONMENT)/dns/terraform.tfstate" > /dev/null
	@echo "$(COLOR_GREEN)  ✓ All 5 states initialized$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ [2/5] Applying network state (~2 min)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Creating: VPC, subnets, NAT gateway, route tables$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dev && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ Network ready$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ [3/5] Applying EKS state (~15 min, đi pha cà phê)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Creating in order:$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    1. EKS control plane (~10 min, AWS managed)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    2. Managed node group (~3 min)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    3. AWS LB Controller via Helm (~1 min)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    4. External Secrets Operator via Helm (~1 min)$(COLOR_RESET)"
	@cd $(ENVS_DIR)/eks && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ EKS ready$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Configuring kubectl to talk to new cluster...$(COLOR_RESET)"
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	@echo "$(COLOR_BLUE)▶ Waiting for nodes to be Ready...$(COLOR_RESET)"
	@kubectl wait --for=condition=Ready nodes --all --timeout=300s
	@NODE_COUNT=$$(kubectl get nodes --no-headers | wc -l); \
	echo "$(COLOR_GREEN)  ✓ $$NODE_COUNT nodes Ready$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ [4/5] Applying RDS state (~5 min)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Creating: PostgreSQL 15, KMS key, parameter group, monitoring role$(COLOR_RESET)"
	@cd $(ENVS_DIR)/rds && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ RDS ready$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ [5/5] Applying Secrets state (~30s)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Creating: JWT_SECRET, Grafana admin password, KMS key$(COLOR_RESET)"
	@cd $(ENVS_DIR)/secrets && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ Secrets created$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Stage 1 complete$(COLOR_RESET)"

# ─── Stage 2: DNS Phase 1 (ACM cert + Route53 zone) ────────────────────────
.PHONY: _stage-2-dns-phase1
_stage-2-dns-phase1:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 2/7: DNS Phase 1 — ACM Certificate$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Why 2 phases? ALB chưa tồn tại nên không thể tạo Route53 A record$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Phase 1: tạo ACM cert + DNS validation records$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Phase 2 (sau): tạo A records trỏ vào ALB$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Setting alb_exists = false in terraform.tfvars...$(COLOR_RESET)"
	@sed -i.bak 's/alb_exists = true/alb_exists = false/g' $(ENVS_DIR)/dns/terraform.tfvars 2>/dev/null || true
	@grep -q '^alb_exists' $(ENVS_DIR)/dns/terraform.tfvars || echo 'alb_exists = false' >> $(ENVS_DIR)/dns/terraform.tfvars
	@echo "$(COLOR_BLUE)▶ Applying DNS state (Phase 1)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Creating: ACM cert (DNS validation), Route53 CNAME validation records$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ DNS Phase 1 applied$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Waiting for ACM cert to be ISSUED...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  AWS verifies domain ownership via DNS CNAME records$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Usually takes 1-3 min. Max wait: 10 min.$(COLOR_RESET)"
	@CERT_ARN=$$(cd $(ENVS_DIR)/dns && terraform output -raw acm_certificate_arn 2>/dev/null); \
	echo "  $(COLOR_GRAY)→ Cert ARN: $$CERT_ARN$(COLOR_RESET)"; \
	START=$$(date +%s); \
	for i in $$(seq 1 30); do \
	  NOW=$$(date +%s); \
	  ELAPSED=$$((NOW - START)); \
	  STATUS=$$(aws acm describe-certificate --certificate-arn $$CERT_ARN \
	    --region $(REGION) --query 'Certificate.Status' --output text 2>/dev/null); \
	  if [ "$$STATUS" = "ISSUED" ]; then \
	    echo "$(COLOR_GREEN)  ✓ ACM cert ISSUED after $${ELAPSED}s$(COLOR_RESET)"; exit 0; \
	  fi; \
	  echo "  [$${ELAPSED}s] Attempt $$i/30: status=$$STATUS, waiting 20s..."; \
	  sleep 20; \
	done; \
	echo "$(COLOR_RED)  ✗ ACM cert not issued after 10 min$(COLOR_RESET)"; \
	echo "$(COLOR_YELLOW)    Debug: check Route53 validation records$(COLOR_RESET)"; \
	exit 1
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Stage 2 complete$(COLOR_RESET)"

# ─── Stage 3: Sync Helm values ─────────────────────────────────────────────
.PHONY: _stage-3-sync-helm-values
_stage-3-sync-helm-values:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 3/7: Sync Helm Values với TF outputs$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Why? RDS endpoint, ACM cert ARN, RDS secret name đổi mỗi lần recreate$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Script này đọc TF outputs → update file Helm values trong config repo$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Sau đó commit + push → ArgoCD sẽ pick up$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running update-helm-values.sh --commit...$(COLOR_RESET)"
	@./scripts/update-helm-values.sh --commit
	@echo "$(COLOR_GREEN)  ✓ Config repo updated and pushed$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Stage 3 complete$(COLOR_RESET)"

# ─── Stage 4: Install ArgoCD + Bootstrap apps ──────────────────────────────
.PHONY: _stage-4-argocd
_stage-4-argocd:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 4/7: ArgoCD + Apps Bootstrap (~10 min)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@$(MAKE) _install-argocd
	@$(MAKE) _bootstrap-apps
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Stage 4 complete$(COLOR_RESET)"

.PHONY: _install-argocd
_install-argocd:
	@echo ""
	@echo "$(COLOR_BLUE)▶ [1/2] Installing ArgoCD...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Note: ArgoCD doesn't manage itself (chicken-and-egg)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Installing from official manifest with --server-side$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  (--server-side avoids 'annotation too long' error for large CRDs)$(COLOR_RESET)"
	@kubectl get namespace $(ARGOCD_NAMESPACE) >/dev/null 2>&1 || { \
	  echo "  $(COLOR_GRAY)→ Creating namespace argocd$(COLOR_RESET)"; \
	  kubectl create namespace $(ARGOCD_NAMESPACE); }
	@echo "  $(COLOR_GRAY)→ Applying ArgoCD manifests (server-side)...$(COLOR_RESET)"
	@kubectl apply -n $(ARGOCD_NAMESPACE) \
	  -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml \
	  --server-side > /dev/null
	@echo "$(COLOR_BLUE)▶ Waiting for ArgoCD deployments (~3 min)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Deployments: argocd-server, repo-server, applicationset, dex, notifications$(COLOR_RESET)"
	@kubectl wait --for=condition=Available deployment --all \
	  -n $(ARGOCD_NAMESPACE) --timeout=300s
	@POD_COUNT=$$(kubectl get pods -n $(ARGOCD_NAMESPACE) --no-headers | grep -c Running); \
	echo "$(COLOR_GREEN)  ✓ ArgoCD installed ($$POD_COUNT pods Running)$(COLOR_RESET)"

.PHONY: _bootstrap-apps
_bootstrap-apps:
	@echo ""
	@echo "$(COLOR_BLUE)▶ [2/2] Bootstrapping ArgoCD applications...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Pre-check: External Secrets Operator must be ready$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Why? ESO installed by Terraform (not ArgoCD). ArgoCD apps depend on it.$(COLOR_RESET)"
	@kubectl wait --for=condition=Available deployment/external-secrets \
	  -n external-secrets --timeout=180s
	@kubectl get crd externalsecrets.external-secrets.io >/dev/null
	@echo "$(COLOR_GREEN)  ✓ ESO ready, CRDs installed$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Pre-step: Apply ClusterSecretStore BEFORE monitoring apps$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Why? grafana-admin-secret ExternalSecret needs ClusterSecretStore$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  to exist BEFORE monitoring-extras syncs. Otherwise Health=Degraded.$(COLOR_RESET)"
	@kubectl apply -f $(CONFIG_REPO)/apps/task-manager/overlays/dev/secret-store.yaml > /dev/null || true
	@echo "  $(COLOR_GRAY)→ Verifying ClusterSecretStore is ready...$(COLOR_RESET)"
	@for i in $$(seq 1 12); do \
	  STATUS=$$(kubectl get clustersecretstore aws-secrets-manager \
	    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown"); \
	  if [ "$$STATUS" = "True" ]; then \
	    echo "$(COLOR_GREEN)  ✓ ClusterSecretStore ready$(COLOR_RESET)"; break; \
	  fi; \
	  echo "  [Attempt $$i/12] ClusterSecretStore status: $$STATUS, waiting 10s..."; \
	  sleep 10; \
	done
	@echo ""
	@echo "$(COLOR_BLUE)▶ Tier 1: Apply monitoring + tools ArgoCD apps$(COLOR_RESET)"
	@echo "  $(COLOR_GRAY)→ Applying monitoring-extras (StorageClass, grafana secret)$(COLOR_RESET)"
	@kubectl apply -f $(CONFIG_REPO)/platform/argocd/apps/monitoring-extras.yaml > /dev/null
	@echo "  $(COLOR_GRAY)→ Applying kube-prometheus-stack$(COLOR_RESET)"
	@kubectl apply -f $(CONFIG_REPO)/platform/argocd/apps/kube-prometheus-stack.yaml > /dev/null
	@echo "  $(COLOR_GRAY)→ Applying argo-rollouts$(COLOR_RESET)"
	@kubectl apply -f $(CONFIG_REPO)/platform/argocd/apps/argo-rollouts.yaml > /dev/null
	@echo "  $(COLOR_GRAY)→ Applying grafana-dashboards$(COLOR_RESET)"
	@kubectl apply -f $(CONFIG_REPO)/platform/argocd/apps/grafana-dashboards.yaml > /dev/null
	@echo ""
	@echo "$(COLOR_BLUE)▶ Waiting for Tier 1 apps to sync (~5 min, CRDs are slow)...$(COLOR_RESET)"
	@$(MAKE) _wait-app APP=monitoring-extras TIMEOUT=300
	@$(MAKE) _wait-app APP=kube-prometheus-stack TIMEOUT=600
	@$(MAKE) _wait-app APP=argo-rollouts TIMEOUT=300
	@$(MAKE) _wait-app APP=grafana-dashboards TIMEOUT=180
	@echo ""
	@echo "$(COLOR_BLUE)▶ Tier 2: Apply application (task-manager)$(COLOR_RESET)"
	@kubectl apply -f $(CONFIG_REPO)/platform/argocd/apps/task-manager-dev.yaml > /dev/null
	@$(MAKE) _wait-app APP=task-manager-dev TIMEOUT=600
	@echo ""
	@echo "$(COLOR_GREEN)  ✓ All ArgoCD apps Synced + Healthy$(COLOR_RESET)"
# Helper: wait cho 1 ArgoCD application Synced + Healthy
.PHONY: _wait-app
_wait-app:
	@if [ -z "$(APP)" ]; then echo "Usage: make _wait-app APP=name"; exit 1; fi
	@TIMEOUT=$${TIMEOUT:-300}; ELAPSED=0; INTERVAL=15; \
	LAST_SYNC=""; LAST_HEALTH=""; DEGRADED_COUNT=0; \
	echo "  $(COLOR_BLUE)Waiting for ArgoCD app: $(APP) (max $${TIMEOUT}s)$(COLOR_RESET)"; \
	while [ $$ELAPSED -lt $$TIMEOUT ]; do \
	  SYNC=$$(kubectl get application $(APP) -n $(ARGOCD_NAMESPACE) \
	    -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown"); \
	  HEALTH=$$(kubectl get application $(APP) -n $(ARGOCD_NAMESPACE) \
	    -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown"); \
	  if [ "$$SYNC" = "Synced" ] && [ "$$HEALTH" = "Healthy" ]; then \
	    echo "$(COLOR_GREEN)    ✓ $(APP) Synced + Healthy ($${ELAPSED}s)$(COLOR_RESET)"; exit 0; \
	  fi; \
	  if [ "$$SYNC" = "Synced" ] && [ "$$HEALTH" = "Degraded" ]; then \
	    DEGRADED_COUNT=$$((DEGRADED_COUNT + 1)); \
	    DETAIL=$$(kubectl get application $(APP) -n $(ARGOCD_NAMESPACE) \
	      -o jsonpath='{.status.conditions[*].message}' 2>/dev/null | head -c 200); \
	    printf "    [%ds] Sync=%s Health=%s (Degraded#%d) %s\n" \
	      $$ELAPSED $$SYNC $$HEALTH $$DEGRADED_COUNT "$$DETAIL"; \
	    if [ $$DEGRADED_COUNT -ge 8 ]; then \
	      echo "$(COLOR_RED)    ✗ $(APP) stuck Degraded after $${ELAPSED}s - investigating...$(COLOR_RESET)"; \
	      echo "$(COLOR_YELLOW)    Check ExternalSecret status:$(COLOR_RESET)"; \
	      kubectl get externalsecret -A 2>/dev/null || true; \
	      echo "$(COLOR_YELLOW)    Check ClusterSecretStore:$(COLOR_RESET)"; \
	      kubectl get clustersecretstore 2>/dev/null || true; \
	      kubectl describe application $(APP) -n $(ARGOCD_NAMESPACE) | tail -20; \
	      exit 1; \
	    fi; \
	  else \
	    printf "    [%ds] Sync=%s Health=%s\n" $$ELAPSED $$SYNC $$HEALTH; \
	  fi; \
	  sleep $$INTERVAL; ELAPSED=$$((ELAPSED + INTERVAL)); \
	done; \
	echo "$(COLOR_RED)    ✗ $(APP) timeout after $${TIMEOUT}s$(COLOR_RESET)"; \
	echo "$(COLOR_YELLOW)    Debug: kubectl describe application $(APP) -n $(ARGOCD_NAMESPACE)$(COLOR_RESET)"; \
	kubectl describe application $(APP) -n $(ARGOCD_NAMESPACE) | tail -30; \
	exit 1

# ─── Stage 5: Wait ALB ready ───────────────────────────────────────────────
.PHONY: _stage-5-wait-alb
_stage-5-wait-alb:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 5/7: Wait ALBs ready (~3 min)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  AWS Load Balancer Controller creates ALBs from Ingress resources$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  We wait until ALBs have a public DNS hostname$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Waiting for task-manager ALB...$(COLOR_RESET)"
	@START=$$(date +%s); \
	for i in $$(seq 1 30); do \
	  NOW=$$(date +%s); \
	  ELAPSED=$$((NOW - START)); \
	  HOST=$$(kubectl get ingress -n $(NAMESPACE) \
	    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	  if [ -n "$$HOST" ]; then \
	    echo "$(COLOR_GREEN)  ✓ Task-manager ALB ready after $${ELAPSED}s$(COLOR_RESET)"; \
	    echo "  $(COLOR_GRAY)→ DNS: $$HOST$(COLOR_RESET)"; \
	    break; \
	  fi; \
	  echo "  [$${ELAPSED}s] Attempt $$i/30: ALB not yet provisioned, waiting 10s..."; \
	  sleep 10; \
	done
	@echo ""
	@echo "$(COLOR_BLUE)▶ Waiting for Grafana ALB...$(COLOR_RESET)"
	@START=$$(date +%s); \
	for i in $$(seq 1 30); do \
	  NOW=$$(date +%s); \
	  ELAPSED=$$((NOW - START)); \
	  HOST=$$(kubectl get ingress -n monitoring \
	    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	  if [ -n "$$HOST" ]; then \
	    echo "$(COLOR_GREEN)  ✓ Grafana ALB ready after $${ELAPSED}s$(COLOR_RESET)"; \
	    echo "  $(COLOR_GRAY)→ DNS: $$HOST$(COLOR_RESET)"; \
	    break; \
	  fi; \
	  echo "  [$${ELAPSED}s] Attempt $$i/30: ALB not yet provisioned, waiting 10s..."; \
	  sleep 10; \
	done
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Stage 5 complete$(COLOR_RESET)"

# ─── Stage 6: DNS Phase 2 (Route53 records → ALB) ──────────────────────────
.PHONY: _stage-6-dns-phase2
_stage-6-dns-phase2:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 6/7: DNS Phase 2 — Route53 → ALB$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Now that ALBs exist, create A (ALIAS) records pointing to them$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Setting alb_exists = true in terraform.tfvars...$(COLOR_RESET)"
	@sed -i.bak 's/alb_exists = false/alb_exists = true/g' $(ENVS_DIR)/dns/terraform.tfvars
	@echo "$(COLOR_BLUE)▶ Applying DNS state (Phase 2)...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Creating: A record for task-manager + grafana subdomain$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ DNS records created$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Stage 6 complete$(COLOR_RESET)"

# ─── Stage 7: Verify end-to-end ────────────────────────────────────────────
.PHONY: _stage-7-verify
_stage-7-verify:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)  Stage 7/7: Verify end-to-end$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@$(MAKE) verify

# ============================================================================
# 🔥 DESTROY — Xóa sạch mọi thứ
# ============================================================================
.PHONY: destroy
destroy:  ## Xóa sạch mọi resource (CẨN THẬN)
	@echo ""
	@echo "$(COLOR_RED)$(COLOR_BOLD)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_RED)$(COLOR_BOLD)║   🔥 DESTROY: xóa MỌI resource AWS            ║$(COLOR_RESET)"
	@echo "$(COLOR_RED)$(COLOR_BOLD)║   Estimated time: ~30 minutes                 ║$(COLOR_RESET)"
	@echo "$(COLOR_RED)$(COLOR_BOLD)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)⚠ This will destroy:$(COLOR_RESET)"
	@echo "  • EKS cluster + node group"
	@echo "  • RDS database (all data lost)"
	@echo "  • VPC, subnets, NAT gateway"
	@echo "  • Secrets Manager entries"
	@echo "  • ACM cert, Route53 records"
	@echo ""
	@read -p "Type 'destroy' to confirm: " confirm; \
	if [ "$$confirm" != "destroy" ]; then \
	  echo "$(COLOR_YELLOW)Aborted by user$(COLOR_RESET)"; exit 1; \
	fi
	@SECONDS=0; \
	$(MAKE) _destroy-stage-1-dns-phase2 || true; \
	$(MAKE) _destroy-stage-2-k8s-resources || true; \
	$(MAKE) _cleanup-orphan-albs || true; \
	$(MAKE) _destroy-stage-3-wait-alb-gone || true; \
	$(MAKE) _destroy-stage-4-argocd || true; \
	$(MAKE) _destroy-stage-5-dns-phase1 || { echo "$(COLOR_RED)✗ Stage 5 failed$(COLOR_RESET)"; exit 1; }; \
	$(MAKE) _destroy-stage-6-secrets || exit 1; \
	$(MAKE) _destroy-stage-7-rds || exit 1; \
	$(MAKE) _destroy-stage-8-eks || exit 1; \
	$(MAKE) _destroy-stage-9-network || exit 1; \
	DURATION=$$SECONDS; \
	echo ""; \
	echo "$(COLOR_GREEN)$(COLOR_BOLD)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"; \
	echo "$(COLOR_GREEN)$(COLOR_BOLD)║   ✓ DESTROY COMPLETE in $$(($$DURATION / 60))m $$(($$DURATION % 60))s            ║$(COLOR_RESET)"; \
	echo "$(COLOR_GREEN)$(COLOR_BOLD)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"

# ─── Destroy Stage 1: DNS Phase 2 (xóa A records trước) ───────────────────
.PHONY: _destroy-stage-1-dns-phase2
_destroy-stage-1-dns-phase2:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 1/9: DNS Phase 2 (A records)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Why first? Remove A records BEFORE deleting ALBs$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  (otherwise Route53 records reference dead ALB DNS)$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Setting alb_exists = false...$(COLOR_RESET)"
	@sed -i.bak 's/alb_exists = true/alb_exists = false/g' $(ENVS_DIR)/dns/terraform.tfvars 2>/dev/null || true
	@echo "$(COLOR_BLUE)▶ Applying (this removes A records, keeps ACM cert)...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve
	@echo "$(COLOR_GREEN)  ✓ A records removed$(COLOR_RESET)"

# ─── Destroy Stage 2: Xóa K8s resources (Ingress trước để free ALB) ───────
.PHONY: _destroy-stage-2-k8s-resources
_destroy-stage-2-k8s-resources:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 2/9: K8s Ingress (free ALBs)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Deleting Ingress → AWS LBC will delete the corresponding ALB$(COLOR_RESET)"
	@echo ""
	@if kubectl get nodes >/dev/null 2>&1; then \
	  echo "$(COLOR_BLUE)▶ Deleting Ingress in $(NAMESPACE) namespace...$(COLOR_RESET)"; \
	  kubectl delete ingress --all -n $(NAMESPACE) --ignore-not-found --timeout=60s 2>&1 || true; \
	  echo "$(COLOR_BLUE)▶ Deleting Ingress in monitoring namespace...$(COLOR_RESET)"; \
	  kubectl delete ingress --all -n monitoring --ignore-not-found --timeout=60s 2>&1 || true; \
	  echo "$(COLOR_GREEN)  ✓ Ingress resources deleted$(COLOR_RESET)"; \
	else \
	  echo "$(COLOR_YELLOW)  ⚠ Cluster unreachable — skipping K8s cleanup$(COLOR_RESET)"; \
	  echo "$(COLOR_YELLOW)  → ALBs (if any) will become orphan, cleanup manually$(COLOR_RESET)"; \
	fi

# ─── Destroy Stage 3: Đợi ALB được LBC xóa ────────────────────────────────
.PHONY: _destroy-stage-3-wait-alb-gone
_destroy-stage-3-wait-alb-gone:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 3/9: Wait ALBs deleted (~3 min)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Wait for AWS LB Controller to fully delete ALBs$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  This must complete BEFORE destroying ACM cert$(COLOR_RESET)"
	@echo ""
	@START=$$(date +%s); \
	for i in $$(seq 1 30); do \
	  NOW=$$(date +%s); \
	  ELAPSED=$$((NOW - START)); \
	  COUNT=$$(aws elbv2 describe-load-balancers --region $(REGION) \
	    --query "length(LoadBalancers)" --output text 2>/dev/null || echo "0"); \
	  if [ "$$COUNT" = "0" ] || [ -z "$$COUNT" ]; then \
	    echo "$(COLOR_GREEN)  ✓ All ALBs deleted after $${ELAPSED}s$(COLOR_RESET)"; exit 0; \
	  fi; \
	  echo "  [$${ELAPSED}s] Attempt $$i/30: $$COUNT ALB(s) remaining, waiting 20s..."; \
	  sleep 20; \
	done; \
	echo "$(COLOR_YELLOW)  ⚠ Timeout — some ALBs still exist, continuing anyway$(COLOR_RESET)"

# ─── Helper: Cleanup orphan ALBs trong VPC ────────────────────────────────
# 
# Triết lý: KHÔNG tin vào AWS LB Controller cleanup tự động.
# Khi destroy EKS, LBC pod chết → ALBs có thể bị orphan.
# Cleanup explicit qua AWS CLI để chắc chắn.
.PHONY: _cleanup-orphan-albs
_cleanup-orphan-albs:
	@echo ""
	@echo "$(COLOR_BLUE)▶ Cleanup orphan ALBs in VPC...$(COLOR_RESET)"
	@VPC_ID=$$(cd $(ENVS_DIR)/dev && terraform state show 'module.vpc.aws_vpc.this[0]' 2>/dev/null | \
	  grep '^    id' | awk '{print $$3}' | tr -d '"' || echo ""); \
	if [ -z "$$VPC_ID" ]; then \
	  echo "$(COLOR_YELLOW)  ⚠ No VPC ID (network state may be empty), skipping$(COLOR_RESET)"; \
	  exit 0; \
	fi; \
	echo "  $(COLOR_GRAY)→ VPC: $$VPC_ID$(COLOR_RESET)"; \
	ALB_ARNS=$$(aws elbv2 describe-load-balancers \
	  --region $(REGION) \
	  --query "LoadBalancers[?VpcId=='$$VPC_ID'].LoadBalancerArn" \
	  --output text 2>/dev/null); \
	if [ -z "$$ALB_ARNS" ] || [ "$$ALB_ARNS" = "None" ]; then \
	  echo "$(COLOR_GREEN)  ✓ No ALBs in VPC$(COLOR_RESET)"; \
	else \
	  echo "  $(COLOR_GRAY)→ Found ALB(s) to delete$(COLOR_RESET)"; \
	  for arn in $$ALB_ARNS; do \
	    NAME=$$(echo $$arn | awk -F'/' '{print $$(NF-1)}'); \
	    echo "  $(COLOR_GRAY)→ Deleting ALB: $$NAME$(COLOR_RESET)"; \
	    aws elbv2 delete-load-balancer \
	      --load-balancer-arn $$arn \
	      --region $(REGION) || true; \
	  done; \
	  echo "  $(COLOR_GRAY)→ Waiting for ALBs to disappear (3 consecutive zeros)...$(COLOR_RESET)"; \
	  ZERO_COUNT=0; \
	  for i in $$(seq 1 30); do \
	    COUNT=$$(aws elbv2 describe-load-balancers \
	      --region $(REGION) \
	      --query "length(LoadBalancers[?VpcId=='$$VPC_ID'])" \
	      --output text 2>/dev/null || echo "0"); \
	    if [ "$$COUNT" = "0" ]; then \
	      ZERO_COUNT=$$((ZERO_COUNT + 1)); \
	      echo "  $(COLOR_GRAY)[$$((i*10))s] ALB count=0 (confirmation $$ZERO_COUNT/3)$(COLOR_RESET)"; \
	      if [ $$ZERO_COUNT -ge 3 ]; then \
	        echo "$(COLOR_GREEN)  ✓ All ALBs confirmed deleted$(COLOR_RESET)"; \
	        break; \
	      fi; \
	    else \
	      ZERO_COUNT=0; \
	      echo "  $(COLOR_GRAY)[$$((i*10))s] $$COUNT ALB(s) still exist, waiting...$(COLOR_RESET)"; \
	    fi; \
	    sleep 10; \
	  done; \
	fi
# ─── Destroy Stage 4: ArgoCD apps + finalizers ────────────────────────────
.PHONY: _destroy-stage-4-argocd
_destroy-stage-4-argocd:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 4/9: ArgoCD applications$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Cascade delete: ArgoCD apps → all K8s resources they manage$(COLOR_RESET)"
	@echo ""
	@if kubectl get nodes >/dev/null 2>&1; then \
	  echo "$(COLOR_BLUE)▶ Removing finalizers from ArgoCD apps (avoid stuck delete)...$(COLOR_RESET)"; \
	  kubectl get applications -n $(ARGOCD_NAMESPACE) --no-headers 2>/dev/null | \
	    awk '{print $$1}' | while read app; do \
	      if [ -n "$$app" ]; then \
	        echo "  $(COLOR_GRAY)→ patching $$app$(COLOR_RESET)"; \
	        kubectl patch application $$app -n $(ARGOCD_NAMESPACE) \
	          --type json \
	          -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true; \
	      fi; \
	    done; \
	  echo "$(COLOR_BLUE)▶ Deleting all ArgoCD applications (cascade)...$(COLOR_RESET)"; \
	  kubectl delete applications --all -n $(ARGOCD_NAMESPACE) \
	    --cascade=foreground --timeout=180s 2>&1 || true; \
	  echo "$(COLOR_GREEN)  ✓ ArgoCD apps deleted$(COLOR_RESET)"; \
	else \
	  echo "$(COLOR_YELLOW)  ⚠ Cluster unreachable, skipping$(COLOR_RESET)"; \
	fi

# ─── Destroy Stage 5: DNS Phase 1 (ACM cert) ──────────────────────────────
.PHONY: _destroy-stage-5-dns-phase1
_destroy-stage-5-dns-phase1:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 5/9: ACM cert + validation records$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  AWS may take 5-15 min to detach cert from deleted ALBs$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  This is 'eventual consistency' — we'll poll every 30s$(COLOR_RESET)"
	@echo ""
	@CERT_ARN=$$(cd $(ENVS_DIR)/dns && terraform output -raw acm_certificate_arn 2>/dev/null || echo ""); \
	if [ -z "$$CERT_ARN" ]; then \
	  echo "$(COLOR_YELLOW)  ⚠ No ACM cert ARN in state. Maybe already destroyed.$(COLOR_RESET)"; \
	else \
	  echo "$(COLOR_BLUE)▶ Checking if ACM cert is free...$(COLOR_RESET)"; \
	  echo "  $(COLOR_GRAY)→ Cert ARN: $$CERT_ARN$(COLOR_RESET)"; \
	  echo "  $(COLOR_GRAY)→ Will check every 30s, max wait 15 min$(COLOR_RESET)"; \
	  echo "  $(COLOR_GRAY)→ Press Ctrl+C ONLY if you're sure it's truly stuck$(COLOR_RESET)"; \
	  echo ""; \
	  START=$$(date +%s); \
	  FREE=false; \
	  for i in $$(seq 1 30); do \
	    NOW=$$(date +%s); \
	    ELAPSED=$$((NOW - START)); \
	    IN_USE=$$(aws acm describe-certificate \
	      --certificate-arn $$CERT_ARN \
	      --region $(REGION) \
	      --query 'Certificate.InUseBy' \
	      --output text 2>/dev/null); \
	    if [ -z "$$IN_USE" ] || [ "$$IN_USE" = "None" ]; then \
	      echo "$(COLOR_GREEN)  ✓ ACM cert is FREE after $${ELAPSED}s$(COLOR_RESET)"; \
	      FREE=true; break; \
	    fi; \
	    echo "  [$${ELAPSED}s] Attempt $$i/30: still in use by:"; \
	    echo "         $(COLOR_GRAY)→ $$IN_USE$(COLOR_RESET)"; \
	    echo "         Sleeping 30s..."; \
	    sleep 30; \
	  done; \
	  if [ "$$FREE" = "false" ]; then \
	    echo ""; \
	    echo "$(COLOR_RED)  ✗ ACM cert STILL in use after 15 min$(COLOR_RESET)"; \
	    echo ""; \
	    echo "$(COLOR_YELLOW)  📋 Workaround: orphan cert in AWS, remove from TF state$(COLOR_RESET)"; \
	    echo "$(COLOR_YELLOW)  Run these commands manually:$(COLOR_RESET)"; \
	    echo ""; \
	    echo "$(COLOR_CYAN)    cd $(ENVS_DIR)/dns$(COLOR_RESET)"; \
	    echo "$(COLOR_CYAN)    terraform state list | grep -E 'acm|cert_validation' | xargs -I{} terraform state rm {}$(COLOR_RESET)"; \
	    echo "$(COLOR_CYAN)    terraform destroy -auto-approve$(COLOR_RESET)"; \
	    echo ""; \
	    echo "$(COLOR_YELLOW)  Then delete cert in AWS Console later (ACM is FREE).$(COLOR_RESET)"; \
	    echo "$(COLOR_YELLOW)  After workaround, continue with: make _destroy-stage-6-secrets$(COLOR_RESET)"; \
	    exit 1; \
	  fi; \
	fi
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running terraform destroy on DNS state...$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  You'll see terraform output below — this is NORMAL, not stuck$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dns && terraform destroy -auto-approve
	@echo "$(COLOR_GREEN)  ✓ DNS resources destroyed$(COLOR_RESET)"

# ─── Destroy Stage 6: Secrets ─────────────────────────────────────────────
.PHONY: _destroy-stage-6-secrets
_destroy-stage-6-secrets:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 6/9: Secrets Manager + KMS$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Deleting: JWT secret, Grafana secret, KMS encryption key$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running terraform destroy on secrets state...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/secrets && terraform destroy -auto-approve
	@echo "$(COLOR_GREEN)  ✓ Secrets destroyed$(COLOR_RESET)"

# ─── Destroy Stage 7: RDS ─────────────────────────────────────────────────
.PHONY: _destroy-stage-7-rds
_destroy-stage-7-rds:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 7/9: RDS PostgreSQL (~5 min)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Deleting in order:$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    1. Master user secret (Secrets Manager auto-managed)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    2. DB instance$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    3. Subnet group, parameter group, security group$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    4. KMS encryption key$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)  ⚠ All data in DB will be permanently lost$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running terraform destroy on RDS state...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/rds && terraform destroy -auto-approve
	@echo "$(COLOR_GREEN)  ✓ RDS destroyed$(COLOR_RESET)"

# ─── Destroy Stage 8: EKS ─────────────────────────────────────────────────
.PHONY: _destroy-stage-8-eks
_destroy-stage-8-eks:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 8/9: EKS Cluster (~15 min)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Deleting in order (Terraform will show progress):$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    1. Helm releases (LBC, ESO) — ~2 min$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    2. Managed node group — ~5 min$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    3. EKS addons (vpc-cni, coredns, kube-proxy)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    4. EKS control plane — ~5 min$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    5. IAM roles (IRSA), CloudWatch log group$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    6. KMS encryption key$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running terraform destroy on EKS state...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/eks && terraform destroy -auto-approve
	@echo "$(COLOR_GREEN)  ✓ EKS destroyed$(COLOR_RESET)"

# ─── Destroy Stage 9: Network với full orphan cleanup ──────────────────────
.PHONY: _destroy-stage-9-network
_destroy-stage-9-network:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)  Destroy 9/9: Network + orphan cleanup$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_RED)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)  Final step. Cleanup orphan resources before terraform destroy:$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    0. ALBs (Layer 2 fallback — in case some leaked through)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    1. ENIs (left by VPC CNI, ALB Controller)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    2. Elastic IPs (left by NAT Gateway)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    3. Security Groups (left by ALB Controller)$(COLOR_RESET)"
	@echo ""
	@# Layer 2 — defense in depth
	@$(MAKE) _cleanup-orphan-albs || true
	@$(MAKE) _cleanup-network-orphans
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running terraform destroy on network state...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dev && terraform destroy -auto-approve
	@echo "$(COLOR_GREEN)  ✓ Network destroyed$(COLOR_RESET)"

# Sub-helper: cleanup orphan resources trong VPC
.PHONY: _cleanup-network-orphans
_cleanup-network-orphans:
	@VPC_ID=$$(cd $(ENVS_DIR)/dev && terraform state show 'module.vpc.aws_vpc.this[0]' 2>/dev/null | \
	  grep '^    id' | awk '{print $$3}' | tr -d '"' || echo ""); \
	if [ -z "$$VPC_ID" ]; then \
	  echo "$(COLOR_YELLOW)  ⚠ Cannot find VPC ID, skipping orphan cleanup$(COLOR_RESET)"; \
	  exit 0; \
	fi; \
	echo "$(COLOR_BLUE)▶ Working on VPC: $$VPC_ID$(COLOR_RESET)"; \
	echo ""; \
	echo "$(COLOR_BLUE)▶ [1/3] Cleanup orphan ENIs...$(COLOR_RESET)"; \
	echo "  $(COLOR_GRAY)→ Sleep 60s for AWS to release ENIs after ALB deletion$(COLOR_RESET)"; \
	sleep 60; \
	ENI_IDS=$$(aws ec2 describe-network-interfaces \
	  --filters "Name=vpc-id,Values=$$VPC_ID" \
	  --region $(REGION) \
	  --query 'NetworkInterfaces[].NetworkInterfaceId' \
	  --output text 2>/dev/null); \
	if [ -n "$$ENI_IDS" ]; then \
	  for eni in $$ENI_IDS; do \
	    echo "  $(COLOR_GRAY)→ Processing $$eni$(COLOR_RESET)"; \
	    STATUS=$$(aws ec2 describe-network-interfaces \
	      --network-interface-ids $$eni \
	      --region $(REGION) \
	      --query 'NetworkInterfaces[0].Status' --output text 2>/dev/null); \
	    if [ "$$STATUS" = "in-use" ]; then \
	      ATTACH_ID=$$(aws ec2 describe-network-interfaces \
	        --network-interface-ids $$eni \
	        --region $(REGION) \
	        --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null); \
	      if [ -n "$$ATTACH_ID" ] && [ "$$ATTACH_ID" != "None" ]; then \
	        echo "    $(COLOR_GRAY)Detaching $$ATTACH_ID...$(COLOR_RESET)"; \
	        aws ec2 detach-network-interface --attachment-id $$ATTACH_ID \
	          --force --region $(REGION) 2>/dev/null || true; \
	        sleep 5; \
	      fi; \
	    fi; \
	    aws ec2 delete-network-interface --network-interface-id $$eni \
	      --region $(REGION) 2>&1 | head -3 || true; \
	  done; \
	  echo "$(COLOR_GREEN)  ✓ ENIs cleaned$(COLOR_RESET)"; \
	else \
	  echo "  $(COLOR_GRAY)→ No orphan ENIs$(COLOR_RESET)"; \
	fi; \
	echo ""; \
	echo "$(COLOR_BLUE)▶ [2/3] Cleanup orphan Elastic IPs...$(COLOR_RESET)"; \
	EIP_ALLOCS=$$(aws ec2 describe-addresses --region $(REGION) \
	  --query 'Addresses[].AllocationId' --output text 2>/dev/null); \
	if [ -n "$$EIP_ALLOCS" ]; then \
	  for alloc in $$EIP_ALLOCS; do \
	    ASSOC_ID=$$(aws ec2 describe-addresses --allocation-ids $$alloc \
	      --region $(REGION) \
	      --query 'Addresses[0].AssociationId' --output text 2>/dev/null); \
	    if [ -n "$$ASSOC_ID" ] && [ "$$ASSOC_ID" != "None" ]; then \
	      echo "  $(COLOR_GRAY)→ Disassociating $$ASSOC_ID$(COLOR_RESET)"; \
	      aws ec2 disassociate-address --association-id $$ASSOC_ID \
	        --region $(REGION) 2>/dev/null || true; \
	    fi; \
	    echo "  $(COLOR_GRAY)→ Releasing $$alloc$(COLOR_RESET)"; \
	    aws ec2 release-address --allocation-id $$alloc \
	      --region $(REGION) 2>&1 | head -3 || true; \
	  done; \
	  echo "$(COLOR_GREEN)  ✓ EIPs released$(COLOR_RESET)"; \
	else \
	  echo "  $(COLOR_GRAY)→ No orphan EIPs$(COLOR_RESET)"; \
	fi; \
	echo ""; \
	echo "$(COLOR_BLUE)▶ [3/3] Cleanup orphan Security Groups...$(COLOR_RESET)"; \
	SG_IDS=$$(aws ec2 describe-security-groups \
	  --filters "Name=vpc-id,Values=$$VPC_ID" \
	  --region $(REGION) \
	  --query "SecurityGroups[?GroupName!='default'].GroupId" \
	  --output text 2>/dev/null); \
	if [ -n "$$SG_IDS" ]; then \
	  for sg in $$SG_IDS; do \
	    echo "  $(COLOR_GRAY)→ Revoking rules in $$sg$(COLOR_RESET)"; \
	    INGRESS=$$(aws ec2 describe-security-groups --group-ids $$sg \
	      --region $(REGION) \
	      --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null); \
	    if [ "$$INGRESS" != "[]" ] && [ -n "$$INGRESS" ]; then \
	      echo "$$INGRESS" > /tmp/sg-ingress-$$sg.json; \
	      aws ec2 revoke-security-group-ingress --group-id $$sg \
	        --ip-permissions file:///tmp/sg-ingress-$$sg.json \
	        --region $(REGION) 2>&1 | head -2 || true; \
	      rm -f /tmp/sg-ingress-$$sg.json; \
	    fi; \
	    EGRESS=$$(aws ec2 describe-security-groups --group-ids $$sg \
	      --region $(REGION) \
	      --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null); \
	    if [ "$$EGRESS" != "[]" ] && [ -n "$$EGRESS" ]; then \
	      echo "$$EGRESS" > /tmp/sg-egress-$$sg.json; \
	      aws ec2 revoke-security-group-egress --group-id $$sg \
	        --ip-permissions file:///tmp/sg-egress-$$sg.json \
	        --region $(REGION) 2>&1 | head -2 || true; \
	      rm -f /tmp/sg-egress-$$sg.json; \
	    fi; \
	  done; \
	  echo "  $(COLOR_GRAY)→ Now deleting SGs (rules cleared)$(COLOR_RESET)"; \
	  for sg in $$SG_IDS; do \
	    aws ec2 delete-security-group --group-id $$sg \
	      --region $(REGION) 2>&1 | head -3 || true; \
	  done; \
	  echo "$(COLOR_GREEN)  ✓ SGs cleaned$(COLOR_RESET)"; \
	else \
	  echo "  $(COLOR_GRAY)→ No orphan SGs$(COLOR_RESET)"; \
	fi
	@echo ""
	@echo "$(COLOR_BLUE)▶ Running terraform destroy on network state...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dev && terraform destroy -auto-approve
	@echo "$(COLOR_GREEN)  ✓ Network destroyed$(COLOR_RESET)"

# ============================================================================
# 💰 HIBERNATE / WAKE — Tiết kiệm chi phí
# ============================================================================
.PHONY: hibernate
hibernate:  ## 🌙 Tắt compute, giữ data (~70% tiết kiệm)
	@echo ""
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)║   🌙 HIBERNATE: pause compute, keep data      ║$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)What hibernate does:$(COLOR_RESET)"
	@echo "  • Delete Ingress → free ALBs (\$$18/month each saved)"
	@echo "  • Scale EKS nodes to 0 (\$$30/month saved)"
	@echo "  • Stop RDS instance (\$$15/month saved)"
	@echo "  • Keep: VPC, ACM cert, Secrets, EKS control plane"
	@echo ""
	@echo "$(COLOR_BLUE)▶ [1/3] Delete Ingress resources...$(COLOR_RESET)"
	@kubectl delete ingress --all -n $(NAMESPACE) --ignore-not-found 2>&1 || true
	@kubectl delete ingress --all -n monitoring --ignore-not-found 2>&1 || true
	@echo "$(COLOR_BLUE)▶ [2/3] Scale workloads to 0...$(COLOR_RESET)"
	@kubectl scale deployment --all --replicas=0 -n $(NAMESPACE) 2>/dev/null || true
	@kubectl scale statefulset --all --replicas=0 -n $(NAMESPACE) 2>/dev/null || true
	@echo "$(COLOR_BLUE)▶ Waiting for ALBs to be deleted by LBC...$(COLOR_RESET)"
	@for i in $$(seq 1 18); do \
	  COUNT=$$(aws elbv2 describe-load-balancers --region $(REGION) \
	    --query "length(LoadBalancers)" --output text 2>/dev/null || echo "0"); \
	  if [ "$$COUNT" = "0" ] || [ -z "$$COUNT" ]; then \
	    echo "$(COLOR_GREEN)  ✓ ALBs deleted$(COLOR_RESET)"; break; \
	  fi; \
	  echo "  [$$((i*10))s] $$COUNT ALB(s) remaining..."; \
	  sleep 10; \
	done
	@echo "$(COLOR_BLUE)▶ [3/3] Scale EKS node group to 0...$(COLOR_RESET)"
	@NODEGROUP=$$(aws eks list-nodegroups --cluster-name $(CLUSTER_NAME) \
	  --region $(REGION) --query 'nodegroups[0]' --output text 2>/dev/null); \
	if [ -n "$$NODEGROUP" ] && [ "$$NODEGROUP" != "None" ]; then \
	  echo "  $(COLOR_GRAY)→ Node group: $$NODEGROUP$(COLOR_RESET)"; \
	  aws eks update-nodegroup-config --cluster-name $(CLUSTER_NAME) \
	    --nodegroup-name $$NODEGROUP \
	    --scaling-config minSize=0,maxSize=3,desiredSize=0 \
	    --region $(REGION) > /dev/null; \
	  echo "$(COLOR_GREEN)  ✓ Scaling to 0 initiated (~2-3 min to complete)$(COLOR_RESET)"; \
	fi
	@echo "$(COLOR_BLUE)▶ Stopping RDS instance...$(COLOR_RESET)"
	@DB_ID=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_endpoint 2>/dev/null | cut -d'.' -f1); \
	if [ -n "$$DB_ID" ]; then \
	  STATUS=$$(aws rds describe-db-instances --db-instance-identifier $$DB_ID \
	    --region $(REGION) --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null); \
	  if [ "$$STATUS" = "available" ]; then \
	    aws rds stop-db-instance --db-instance-identifier $$DB_ID --region $(REGION) > /dev/null; \
	    echo "$(COLOR_GREEN)  ✓ RDS stop initiated$(COLOR_RESET)"; \
	  else \
	    echo "  $(COLOR_GRAY)→ RDS already in state: $$STATUS$(COLOR_RESET)"; \
	  fi; \
	fi
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ Hibernation complete$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)⚠ AWS auto-resumes RDS after 7 days (limitation)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)Resume with: make wake$(COLOR_RESET)"
	@echo ""

.PHONY: wake
wake:  ## ☀️ Bật lại hệ thống (sau đó chạy make wake-dns)
	@echo ""
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)╔═══════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)║   ☀️  WAKE UP: resume hibernated system       ║$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)╚═══════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)▶ [1/3] Starting RDS (~5-7 min)...$(COLOR_RESET)"
	@DB_ID=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_endpoint 2>/dev/null | cut -d'.' -f1); \
	if [ -n "$$DB_ID" ]; then \
	  STATUS=$$(aws rds describe-db-instances --db-instance-identifier $$DB_ID \
	    --region $(REGION) --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null); \
	  echo "  $(COLOR_GRAY)→ Current state: $$STATUS$(COLOR_RESET)"; \
	  if [ "$$STATUS" = "stopped" ]; then \
	    aws rds start-db-instance --db-instance-identifier $$DB_ID --region $(REGION) > /dev/null; \
	    echo "  $(COLOR_GRAY)→ Waiting for RDS available...$(COLOR_RESET)"; \
	    aws rds wait db-instance-available --db-instance-identifier $$DB_ID --region $(REGION); \
	    echo "$(COLOR_GREEN)  ✓ RDS available$(COLOR_RESET)"; \
	  fi; \
	fi
	@echo "$(COLOR_BLUE)▶ [2/3] Scaling EKS node group up...$(COLOR_RESET)"
	@NODEGROUP=$$(aws eks list-nodegroups --cluster-name $(CLUSTER_NAME) \
	  --region $(REGION) --query 'nodegroups[0]' --output text 2>/dev/null); \
	if [ -n "$$NODEGROUP" ] && [ "$$NODEGROUP" != "None" ]; then \
	  aws eks update-nodegroup-config --cluster-name $(CLUSTER_NAME) \
	    --nodegroup-name $$NODEGROUP \
	    --scaling-config minSize=1,maxSize=3,desiredSize=2 \
	    --region $(REGION) > /dev/null; \
	  echo "  $(COLOR_GRAY)→ Waiting for nodes Ready (~3 min)...$(COLOR_RESET)"; \
	  for i in $$(seq 1 18); do \
	    READY=$$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0"); \
	    if [ "$$READY" -ge "1" ]; then \
	      echo "$(COLOR_GREEN)  ✓ $$READY nodes Ready$(COLOR_RESET)"; break; \
	    fi; \
	    echo "  [$$((i*10))s] $$READY nodes Ready, waiting..."; sleep 10; \
	  done; \
	fi
	@echo "$(COLOR_BLUE)▶ [3/3] Triggering ArgoCD sync (recreates Ingress → new ALBs)...$(COLOR_RESET)"
	@kubectl patch application task-manager-dev -n argocd \
	  --type merge -p '{"operation":{"sync":{"prune":true,"revision":"HEAD"}}}' 2>/dev/null || true
	@kubectl patch application kube-prometheus-stack -n argocd \
	  --type merge -p '{"operation":{"sync":{"prune":true,"revision":"HEAD"}}}' 2>/dev/null || true
	@echo "$(COLOR_GREEN)  ✓ Sync triggered$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)$(COLOR_BOLD)⚠ Important next step:$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)  New ALBs have new DNS names. Wait ~5 min, then run:$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)    make wake-dns$(COLOR_RESET)"
	@echo ""

.PHONY: wake-dns
wake-dns:  ## ☀️ Cập nhật DNS sau khi wake (ALB DNS mới)
	@echo ""
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)═══ Update DNS records to point to new ALBs ═══$(COLOR_RESET)"
	@$(MAKE) _stage-5-wait-alb
	@$(MAKE) _stage-6-dns-phase2
	@echo ""
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✓ System fully awake$(COLOR_RESET)"
	@$(MAKE) verify

# ============================================================================
# 🔍 STATUS & VERIFY
# ============================================================================
.PHONY: status
status:  ## Check trạng thái infrastructure
	@echo ""
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)  Infrastructure Status$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)► EKS Cluster$(COLOR_RESET)"
	@aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) \
	  --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' \
	  --output table 2>/dev/null || echo "  ✗ Cluster not found"
	@echo ""
	@echo "$(COLOR_BLUE)► EKS Node Groups$(COLOR_RESET)"
	@aws eks list-nodegroups --cluster-name $(CLUSTER_NAME) --region $(REGION) \
	  --query 'nodegroups[]' --output text 2>/dev/null | while read ng; do \
	    if [ -n "$$ng" ]; then \
	      aws eks describe-nodegroup --cluster-name $(CLUSTER_NAME) \
	        --nodegroup-name $$ng --region $(REGION) \
	        --query 'nodegroup.{Name:nodegroupName,Status:status,Desired:scalingConfig.desiredSize}' \
	        --output table; \
	    fi; \
	  done
	@echo ""
	@echo "$(COLOR_BLUE)► RDS$(COLOR_RESET)"
	@aws rds describe-db-instances --region $(REGION) \
	  --query 'DBInstances[?contains(DBInstanceIdentifier, `devops`)].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass}' \
	  --output table 2>/dev/null || echo "  ✗ No RDS"
	@echo ""
	@echo "$(COLOR_BLUE)► ArgoCD Applications$(COLOR_RESET)"
	@kubectl get applications -n $(ARGOCD_NAMESPACE) 2>/dev/null || echo "  ✗ Cannot connect"
	@echo ""
	@echo "$(COLOR_BLUE)► Workload Pods (task-manager-dev)$(COLOR_RESET)"
	@kubectl get pods -n $(NAMESPACE) --no-headers 2>/dev/null | \
	  awk '{print "  " $$1 ": " $$3}' || echo "  ✗ Cannot connect"
	@echo ""
	@echo "$(COLOR_BLUE)► Monitoring Pods$(COLOR_RESET)"
	@kubectl get pods -n monitoring --no-headers 2>/dev/null | head -8 | \
	  awk '{print "  " $$1 ": " $$3}' || echo "  ✗ Cannot connect"
	@echo ""
	@echo "$(COLOR_BLUE)► Cost-incurring resources NOW$(COLOR_RESET)"
	@NAT=$$(aws ec2 describe-nat-gateways --filter 'Name=state,Values=available' \
	  --region $(REGION) --query 'length(NatGateways)' --output text 2>/dev/null); \
	ALB=$$(aws elbv2 describe-load-balancers --region $(REGION) \
	  --query 'length(LoadBalancers)' --output text 2>/dev/null); \
	echo "  NAT Gateways: $$NAT (× \$$33/month)"; \
	echo "  Load Balancers: $$ALB (× \$$18/month)"
	@echo ""

.PHONY: verify
verify:  ## Verify end-to-end
	@echo ""
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)  End-to-End Verification$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)$(COLOR_BOLD)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)► ExternalSecrets sync status$(COLOR_RESET)"
	@kubectl get externalsecret -A 2>/dev/null | head -10 || echo "  ✗ Cannot get"
	@echo ""
	@echo "$(COLOR_BLUE)► App health check$(COLOR_RESET)"
	@DOMAIN=$$(cd $(ENVS_DIR)/dns && terraform output -raw full_fqdn 2>/dev/null); \
	if [ -n "$$DOMAIN" ]; then \
	  echo "  $(COLOR_GRAY)→ URL: https://$$DOMAIN/api/health/ready$(COLOR_RESET)"; \
	  for i in $$(seq 1 12); do \
	    STATUS=$$(curl -sk -o /dev/null -w "%{http_code}" https://$$DOMAIN/api/health/ready 2>/dev/null); \
	    if [ "$$STATUS" = "200" ]; then \
	      echo "$(COLOR_GREEN)  ✓ HTTP 200 OK$(COLOR_RESET)"; break; \
	    fi; \
	    echo "  [Attempt $$i/12] HTTP $$STATUS, retry in 10s..."; sleep 10; \
	  done; \
	fi
	@echo ""
	@echo "$(COLOR_BLUE)► Grafana endpoint$(COLOR_RESET)"
	@curl -sk -o /dev/null -w "  $(COLOR_GRAY)→ grafana.vantai.click$(COLOR_RESET) → HTTP %{http_code}\n" \
	  https://grafana.vantai.click/api/health 2>/dev/null
	@echo ""
	@echo "$(COLOR_BLUE)► Grafana credentials$(COLOR_RESET)"
	@PASS=$$(kubectl get secret grafana-admin-secret -n monitoring \
	  -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d); \
	if [ -n "$$PASS" ]; then \
	  echo "  Username: admin"; \
	  echo "  Password: $$PASS"; \
	else \
	  echo "  ⚠ Cannot retrieve credentials"; \
	fi
	@echo ""

# ============================================================================
# UTILITIES — Helper commands cho daily use
# ============================================================================
.PHONY: kubeconfig
kubeconfig:  ## Configure kubectl để talk to cluster
	@echo "$(COLOR_BLUE)▶ Updating kubeconfig for cluster $(CLUSTER_NAME)...$(COLOR_RESET)"
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	@echo "$(COLOR_GREEN)✓ kubectl configured$(COLOR_RESET)"

.PHONY: argocd-ui
argocd-ui:  ## Port-forward ArgoCD UI tới http://localhost:8080
	@echo ""
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)  ArgoCD UI Access$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)URL:      https://localhost:8080 (ignore SSL warning)$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)Username: admin$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)Password:$(COLOR_RESET)"
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d
	@echo ""
	@echo ""
	@echo "$(COLOR_YELLOW)Press Ctrl+C to stop port-forward$(COLOR_RESET)"
	@echo ""
	@kubectl port-forward -n argocd svc/argocd-server 8080:443

.PHONY: logs-backend
logs-backend:  ## Tail backend logs
	@kubectl logs -n $(NAMESPACE) -l app=backend --tail=50 -f

.PHONY: logs-frontend
logs-frontend:  ## Tail frontend logs
	@kubectl logs -n $(NAMESPACE) -l app=frontend --tail=50 -f

.PHONY: shell-backend
shell-backend:  ## Mở shell vào 1 backend pod
	@POD=$$(kubectl get pod -n $(NAMESPACE) -l app=backend -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -it -n $(NAMESPACE) $$POD -- sh

.PHONY: clean-tfvars-bak
clean-tfvars-bak:  ## Xóa các file .bak terraform tạo ra
	@find $(ENVS_DIR) -name 'terraform.tfvars.bak' -delete 2>/dev/null || true
	@echo "$(COLOR_GREEN)✓ Cleaned$(COLOR_RESET)"

.PHONY: clean-stage4
clean-stage4:  ## Xóa ArgoCD apps + ClusterSecretStore để retry Stage 4
	@echo ""
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)  Clean Stage 4 resources (ArgoCD apps)$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)▶ Removing finalizers from all ArgoCD apps...$(COLOR_RESET)"
	@kubectl get applications -n $(ARGOCD_NAMESPACE) --no-headers 2>/dev/null | \
	  awk '{print $$1}' | while read app; do \
	    [ -n "$$app" ] && kubectl patch application $$app -n $(ARGOCD_NAMESPACE) \
	      --type json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true; \
	  done
	@echo "$(COLOR_BLUE)▶ Deleting all ArgoCD applications...$(COLOR_RESET)"
	@kubectl delete applications --all -n $(ARGOCD_NAMESPACE) \
	  --cascade=foreground --timeout=120s 2>/dev/null || true
	@echo "$(COLOR_BLUE)▶ Deleting ClusterSecretStore...$(COLOR_RESET)"
	@kubectl delete clustersecretstore aws-secrets-manager 2>/dev/null || true
	@echo "$(COLOR_BLUE)▶ Waiting 10s for resources to settle...$(COLOR_RESET)"
	@sleep 10
	@echo "$(COLOR_GREEN)✓ Stage 4 resources cleaned. Now run: make _stage-4-argocd$(COLOR_RESET)"
	@echo ""