# ============================================================================
# NT548 Task Manager — DevOps Automation (v2.2 — Phase 5.8 secrets integration)
# ============================================================================
# Changes v2.1 → v2.2:
# - tf-apply-secrets nằm trong tf-apply-infrastructure (trước eks → secrets độc lập)
# - k8s-render export BACKEND_SECRET_NAME từ secrets state
# - Xóa k8s-jwt-secret (replaced by ESO ExternalSecret)
# - k8s-deploy không còn dependency vào k8s-jwt-secret
# ============================================================================

# Colors
COLOR_RESET   := \033[0m
COLOR_GREEN   := \033[32m
COLOR_YELLOW  := \033[33m
COLOR_RED     := \033[31m
COLOR_BLUE    := \033[34m

# Project config
PROJECT       := devops
ENVIRONMENT   := dev
REGION        := ap-southeast-1
NAMESPACE     := task-manager-dev
CLUSTER_NAME  := $(PROJECT)-$(ENVIRONMENT)

# Paths
INFRA_DIR        := infrastructure
ENVS_DIR         := $(INFRA_DIR)/envs
BACKEND_CONFIG   := $(INFRA_DIR)/backend-config.hcl
COMMON_TFVARS    := $(INFRA_DIR)/common.tfvars
K8S_OVERLAY      := k8s/overlays/aws

# Image config
DOCKERHUB_USER ?= doanvantai
IMAGE_TAG      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")

.PHONY: help
help:  ## Show this help
	@echo "$(COLOR_BLUE)NT548 Task Manager — Available targets$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?##.*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-25s$(COLOR_RESET) %s\n", $$1, $$2}'

# ============================================================================
# BOOTSTRAP
# ============================================================================

.PHONY: bootstrap
bootstrap:  ## Tạo S3+DynamoDB (CHẠY 1 LẦN)
	@cd $(INFRA_DIR)/bootstrap && terraform init && terraform apply -auto-approve

# ============================================================================
# SETUP
# ============================================================================

.PHONY: setup-symlinks
setup-symlinks:  ## Symlink common.tfvars vào mỗi state
	@for state in dev eks rds secrets dns; do \
	  ln -sf ../../common.tfvars $(ENVS_DIR)/$$state/common.auto.tfvars; \
	  echo "  ✓ $(ENVS_DIR)/$$state/common.auto.tfvars"; \
	done
	@echo "$(COLOR_GREEN)✓ Symlinks created$(COLOR_RESET)"

# ============================================================================
# TERRAFORM INIT — partial backend
# ============================================================================

define tf_init
	@echo "$(COLOR_BLUE)▶ Init $(1) → key=$(ENVIRONMENT)/$(2)/terraform.tfstate ...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/$(1) && \
		terraform init -reconfigure \
			-backend-config=../../backend-config.hcl \
			-backend-config="key=$(ENVIRONMENT)/$(2)/terraform.tfstate"
endef

.PHONY: tf-init-all
tf-init-all: setup-symlinks  ## Init tất cả states
	$(call tf_init,dev,network)
	$(call tf_init,eks,eks)
	$(call tf_init,rds,rds)
	$(call tf_init,secrets,secrets)
	$(call tf_init,dns,dns)
	@echo "$(COLOR_GREEN)✓ All states initialized$(COLOR_RESET)"

# ============================================================================
# TERRAFORM APPLY — granular targets (có thể chạy lẻ)
# ============================================================================

.PHONY: tf-apply-network
tf-apply-network:  ## Apply network (folder=dev)
	@cd $(ENVS_DIR)/dev && terraform apply -auto-approve

.PHONY: tf-apply-eks
tf-apply-eks:  ## Apply EKS (~15 min)
	@cd $(ENVS_DIR)/eks && terraform apply -auto-approve

.PHONY: tf-apply-rds
tf-apply-rds:  ## Apply RDS (~10 min)
	@cd $(ENVS_DIR)/rds && terraform apply -auto-approve

.PHONY: tf-apply-secrets
tf-apply-secrets:  ## Apply secrets state (JWT + KMS)
	@cd $(ENVS_DIR)/secrets && terraform apply -auto-approve

# ⭐ tf-apply-infrastructure — bao gồm tất cả states cần thiết
# Order matters: network → eks → rds (depends on eks SG) → secrets (independent)
.PHONY: tf-apply-infrastructure
tf-apply-infrastructure: tf-apply-network tf-apply-eks tf-apply-rds tf-apply-secrets

.PHONY: tf-apply-dns-phase1
tf-apply-dns-phase1:  ## Apply DNS phase 1: ACM + Hosted Zone
	@echo "$(COLOR_BLUE)▶ DNS Phase 1: ACM + Hosted Zone only$(COLOR_RESET)"
	@sed -i 's/alb_exists = true/alb_exists = false/g' $(ENVS_DIR)/dns/terraform.tfvars || true
	@grep -q '^alb_exists' $(ENVS_DIR)/dns/terraform.tfvars || echo 'alb_exists = false' >> $(ENVS_DIR)/dns/terraform.tfvars
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve

.PHONY: tf-apply-dns-phase2
tf-apply-dns-phase2:  ## Apply DNS phase 2: Route53 record sau khi ALB tồn tại
	@echo "$(COLOR_BLUE)▶ DNS Phase 2: ALB Route53 record$(COLOR_RESET)"
	@sed -i 's/alb_exists = false/alb_exists = true/g' $(ENVS_DIR)/dns/terraform.tfvars
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve

# ============================================================================
# KUBERNETES — render manifests từ TF outputs
# ============================================================================

.PHONY: kubeconfig
kubeconfig:
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)

# ⭐ k8s-render — extract outputs từ TẤT CẢ states (rds, dns, secrets)
# và export làm env vars để envsubst render *.tpl files
.PHONY: k8s-render
k8s-render:  ## Render K8s manifests từ TF outputs
	@echo "$(COLOR_BLUE)▶ Rendering manifests from TF outputs...$(COLOR_RESET)"
	@RDS_ENDPOINT=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_address) && \
	 RDS_SECRET_ARN=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_master_user_secret_arn) && \
	 RDS_SECRET_NAME=$$(echo $$RDS_SECRET_ARN | awk -F: '{print $$NF}' | sed 's/-[A-Za-z0-9]*$$//') && \
	 DB_NAME=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_name) && \
	 BACKEND_SECRET_NAME=$$(cd $(ENVS_DIR)/secrets && terraform output -raw backend_secret_name) && \
	 ACM_CERT_ARN=$$(cd $(ENVS_DIR)/dns && terraform output -raw acm_certificate_arn 2>/dev/null | tr -d '\000-\010\013\014\016-\037' || echo "PENDING") && \
	 APP_FQDN=$$(cd $(ENVS_DIR)/dns && terraform output -raw full_fqdn 2>/dev/null | tr -d '\000-\010\013\014\016-\037' || echo "task-manager.example.com") && \
	 export RDS_ENDPOINT RDS_SECRET_NAME DB_NAME BACKEND_SECRET_NAME ACM_CERT_ARN APP_FQDN \
	        IMAGE_TAG="$(IMAGE_TAG)" DOCKERHUB_USER="$(DOCKERHUB_USER)" && \
	 echo "  RDS_ENDPOINT         = $$RDS_ENDPOINT" && \
	 echo "  RDS_SECRET_NAME      = $$RDS_SECRET_NAME" && \
	 echo "  BACKEND_SECRET_NAME  = $$BACKEND_SECRET_NAME" && \
	 echo "  ACM_CERT_ARN         = $$ACM_CERT_ARN" && \
	 echo "  APP_FQDN             = $$APP_FQDN" && \
	 echo "  IMAGE_TAG            = $$IMAGE_TAG" && \
	 for tpl in $(K8S_OVERLAY)/*.tpl; do \
	   out=$${tpl%.tpl}; \
	   envsubst < $$tpl > $$out; \
	   echo "  ✓ $$out"; \
	 done

.PHONY: k8s-namespace
k8s-namespace:
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

# ─── ⚠️ DEPRECATED in v2.2: JWT giờ do ESO sync, không cần openssl ───
# Giữ lại target để backward compatibility (in cảnh báo)
.PHONY: k8s-jwt-secret
k8s-jwt-secret:
	@echo "$(COLOR_YELLOW)⚠ k8s-jwt-secret is DEPRECATED in Phase 5.8.$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)  JWT_SECRET is now managed via Terraform + ESO.$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)  Pipeline: tf-apply-secrets → ExternalSecret → K8s Secret$(COLOR_RESET)"

# ⭐ k8s-deploy — KHÔNG còn dependency vào k8s-jwt-secret
.PHONY: k8s-deploy
k8s-deploy: kubeconfig k8s-render k8s-namespace
	@cd $(K8S_OVERLAY) && kubectl apply -k .
	@echo "$(COLOR_BLUE)▶ Waiting for ExternalSecrets to sync...$(COLOR_RESET)"
	@kubectl wait --for=condition=Ready externalsecret/backend-secrets -n $(NAMESPACE) --timeout=120s || \
	  echo "$(COLOR_YELLOW)⚠ backend-secrets ExternalSecret not ready in 120s. Check: kubectl describe externalsecret -n $(NAMESPACE)$(COLOR_RESET)"
	@kubectl wait --for=condition=Ready externalsecret/db-credentials -n $(NAMESPACE) --timeout=120s || \
	  echo "$(COLOR_YELLOW)⚠ db-credentials ExternalSecret not ready in 120s$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)▶ Waiting for backend pods...$(COLOR_RESET)"
	@kubectl wait --for=condition=Ready pod -l app=backend -n $(NAMESPACE) --timeout=300s || true

.PHONY: k8s-wait-alb
k8s-wait-alb:
	@for i in $$(seq 1 30); do \
	  HOSTNAME=$$(kubectl get ingress task-manager-aws -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	  if [ -n "$$HOSTNAME" ]; then \
	    echo "$(COLOR_GREEN)✓ ALB ready: $$HOSTNAME$(COLOR_RESET)"; exit 0; \
	  fi; \
	  echo "  ... waiting ($$i/30)"; sleep 10; \
	done

.PHONY: k8s-status
k8s-status:
	@echo "$(COLOR_BLUE)═══ Pods & Workloads ═══$(COLOR_RESET)"
	@kubectl get pods,ingress -n $(NAMESPACE)
	@echo ""
	@echo "$(COLOR_BLUE)═══ ExternalSecrets (ESO sync status) ═══$(COLOR_RESET)"
	@kubectl get externalsecret,secretstore,clustersecretstore -n $(NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "$(COLOR_BLUE)═══ K8s Secrets (auto-managed by ESO) ═══$(COLOR_RESET)"
	@kubectl get secrets -n $(NAMESPACE)

.PHONY: k8s-logs
k8s-logs:
	@kubectl logs -n $(NAMESPACE) -l app=backend --tail=50 -f

# ============================================================================
# SECRET VERIFICATION (debug helpers)
# ============================================================================

.PHONY: verify-secrets
verify-secrets:  ## Kiểm tra secret sync chain hoạt động
	@echo "$(COLOR_BLUE)═══ 1. AWS Secrets Manager ═══$(COLOR_RESET)"
	@BACKEND_NAME=$$(cd $(ENVS_DIR)/secrets && terraform output -raw backend_secret_name); \
	 aws secretsmanager describe-secret --secret-id $$BACKEND_NAME --region $(REGION) \
	   --query '{Name:Name,LastChanged:LastChangedDate}' --output table
	@echo ""
	@echo "$(COLOR_BLUE)═══ 2. ExternalSecret status ═══$(COLOR_RESET)"
	@kubectl get externalsecret backend-secrets -n $(NAMESPACE) -o jsonpath='{.status}' 2>/dev/null | jq . || \
	  echo "$(COLOR_YELLOW)Not yet synced$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)═══ 3. K8s Secret (synced by ESO) ═══$(COLOR_RESET)"
	@kubectl get secret backend-secrets -n $(NAMESPACE) -o jsonpath='{.data}' 2>/dev/null | jq 'keys' || \
	  echo "$(COLOR_YELLOW)Secret not present$(COLOR_RESET)"

# ============================================================================
# END-TO-END
# ============================================================================

.PHONY: deploy-all
deploy-all: tf-init-all tf-apply-infrastructure tf-apply-dns-phase1 k8s-render k8s-deploy k8s-wait-alb tf-apply-dns-phase2
	@cd $(K8S_OVERLAY) && kubectl apply -k .
	@$(MAKE) verify

.PHONY: verify
verify:
	@DOMAIN=$$(cd $(ENVS_DIR)/dns && terraform output -raw full_fqdn) && \
	for i in $$(seq 1 12); do \
	  STATUS=$$(curl -sk -o /dev/null -w "%{http_code}" https://$$DOMAIN/api/health/ready); \
	  if [ "$$STATUS" = "200" ]; then \
	    echo "$(COLOR_GREEN)✓ HTTP $$STATUS$(COLOR_RESET)"; exit 0; \
	  fi; \
	  sleep 10; \
	done

# ============================================================================
# IaC SECURITY SCAN (local — same scans as CI)
# ============================================================================

.PHONY: sec-scan
sec-scan: sec-tfsec sec-checkov sec-trivy  ## Chạy tất cả IaC scanners local

.PHONY: sec-tfsec
sec-tfsec:  ## Scan với tfsec
	@echo "$(COLOR_BLUE)▶ tfsec scan ...$(COLOR_RESET)"
	@command -v tfsec >/dev/null || (echo "$(COLOR_RED)Install: brew install tfsec$(COLOR_RESET)" && exit 1)
	@tfsec $(INFRA_DIR) --soft-fail

.PHONY: sec-checkov
sec-checkov:  ## Scan với Checkov
	@echo "$(COLOR_BLUE)▶ Checkov scan ...$(COLOR_RESET)"
	@command -v checkov >/dev/null || (echo "$(COLOR_RED)Install: pip install checkov$(COLOR_RESET)" && exit 1)
	@checkov -d $(INFRA_DIR) --framework terraform --soft-fail --quiet --compact

.PHONY: sec-trivy
sec-trivy:  ## Scan với Trivy IaC
	@echo "$(COLOR_BLUE)▶ Trivy IaC config scan ...$(COLOR_RESET)"
	@command -v trivy >/dev/null || (echo "$(COLOR_RED)Install: brew install trivy$(COLOR_RESET)" && exit 1)
	@trivy config $(INFRA_DIR) --severity CRITICAL,HIGH --exit-code 0

# ============================================================================
# DESTROY
# ============================================================================

.PHONY: k8s-delete
k8s-delete:
	@echo "$(COLOR_BLUE)▶ Step 1: Delete Ingress → trigger LBC to delete ALB...$(COLOR_RESET)"
	@kubectl delete ingress --all -n $(NAMESPACE) --ignore-not-found || true
	@echo "$(COLOR_BLUE)▶ Step 2: Wait for ALB to be fully deleted by LBC...$(COLOR_RESET)"
	@for i in $$(seq 1 30); do \
	  COUNT=$$(aws elbv2 describe-load-balancers \
	    --region $(REGION) \
	    --query "length(LoadBalancers[?contains(LoadBalancerName, 'taskmana')])" \
	    --output text 2>/dev/null || echo "0"); \
	  if [ "$$COUNT" = "0" ] || [ -z "$$COUNT" ] || [ "$$COUNT" = "None" ]; then \
	    echo "$(COLOR_GREEN)✓ ALB deleted by LBC$(COLOR_RESET)"; break; \
	  fi; \
	  echo "  ... ALB still exists ($$i/30), waiting 20s"; sleep 20; \
	done
	@echo "$(COLOR_BLUE)▶ Step 3: Force delete remaining K8s resources...$(COLOR_RESET)"
	@cd $(K8S_OVERLAY) && kubectl delete -k . --ignore-not-found || true
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found --wait=true || true
	@echo "$(COLOR_BLUE)▶ Step 4: Cleanup orphan ALB Security Groups...$(COLOR_RESET)"
	@VPC_ID=$$(cd $(ENVS_DIR)/dev && terraform output -raw vpc_id 2>/dev/null || echo ""); \
	if [ -n "$$VPC_ID" ]; then \
	  aws ec2 describe-security-groups \
	    --filters "Name=vpc-id,Values=$$VPC_ID" \
	    --region $(REGION) \
	    --query "SecurityGroups[?GroupName!='default'].GroupId" \
	    --output text 2>/dev/null | tr '\t' '\n' | while read sg; do \
	      if [ -n "$$sg" ]; then \
	        echo "  Deleting orphan SG: $$sg"; \
	        aws ec2 delete-security-group --group-id $$sg --region $(REGION) 2>/dev/null || \
	          echo "  $(COLOR_YELLOW)⚠ Could not delete $$sg (may have dependencies)$(COLOR_RESET)"; \
	      fi; \
	    done; \
	fi
	@echo "$(COLOR_GREEN)✓ k8s-delete complete$(COLOR_RESET)"

.PHONY: confirm-destroy
confirm-destroy:
	@read -p "Type 'destroy' to confirm: " confirm; \
	if [ "$$confirm" != "destroy" ]; then \
	  echo "$(COLOR_RED)Aborted$(COLOR_RESET)"; exit 1; \
	fi

.PHONY: tf-destroy-dns-phase2
tf-destroy-dns-phase2:
	@echo "$(COLOR_BLUE)▶ DNS Destroy Phase 2: remove ALB Route53 record$(COLOR_RESET)"
	@sed -i 's/alb_exists = true/alb_exists = false/g' $(ENVS_DIR)/dns/terraform.tfvars || true
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve

.PHONY: tf-destroy-dns-phase1
tf-destroy-dns-phase1:
	@echo "$(COLOR_BLUE)▶ DNS Destroy Phase 1: ACM cert + validation records$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)▶ Verifying cert is not in use before destroying...$(COLOR_RESET)"
	@CERT_ARN=$$(cd $(ENVS_DIR)/dns && terraform output -raw acm_certificate_arn 2>/dev/null || echo ""); \
	if [ -n "$$CERT_ARN" ]; then \
	  IN_USE=$$(aws acm describe-certificate \
	    --certificate-arn $$CERT_ARN \
	    --region $(REGION) \
	    --query 'Certificate.InUseBy' \
	    --output text 2>/dev/null); \
	  if [ -n "$$IN_USE" ] && [ "$$IN_USE" != "None" ]; then \
	    echo "$(COLOR_RED)✗ Cert still in use by: $$IN_USE$(COLOR_RESET)"; \
	    echo "$(COLOR_RED)  Please delete the ALB first, then retry$(COLOR_RESET)"; \
	    echo "$(COLOR_YELLOW)  Run: aws elbv2 delete-load-balancer --load-balancer-arn <ARN> --region $(REGION)$(COLOR_RESET)"; \
	    exit 1; \
	  fi; \
	fi
	@cd $(ENVS_DIR)/dns && terraform destroy -auto-approve

.PHONY: tf-destroy-secrets
tf-destroy-secrets:
	@echo "$(COLOR_BLUE)▶ Destroying Secrets Manager...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/secrets && terraform destroy -auto-approve

.PHONY: tf-destroy-rds
tf-destroy-rds:
	@echo "$(COLOR_BLUE)▶ Destroying RDS (~5 min)...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/rds && terraform destroy -auto-approve

.PHONY: tf-destroy-eks
tf-destroy-eks:
	@echo "$(COLOR_BLUE)▶ Destroying EKS (~15 min)...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/eks && terraform destroy -auto-approve

.PHONY: tf-destroy-network
tf-destroy-network:
	@echo "$(COLOR_BLUE)▶ Destroying Network (VPC, subnets, NAT)...$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)▶ Checking for orphan Security Groups in VPC...$(COLOR_RESET)"
	@VPC_ID=$$(cd $(ENVS_DIR)/dev && terraform output -raw vpc_id 2>/dev/null || echo ""); \
	if [ -n "$$VPC_ID" ]; then \
	  SG_LIST=$$(aws ec2 describe-security-groups \
	    --filters "Name=vpc-id,Values=$$VPC_ID" \
	    --region $(REGION) \
	    --query "SecurityGroups[?GroupName!='default'].GroupId" \
	    --output text 2>/dev/null); \
	  for sg in $$SG_LIST; do \
	    echo "  Deleting orphan SG: $$sg"; \
	    aws ec2 delete-security-group --group-id $$sg --region $(REGION) 2>/dev/null || true; \
	  done; \
	fi
	@cd $(ENVS_DIR)/dev && terraform destroy -auto-approve

# ⭐ DESTROY ALL — đúng thứ tự, có safety checks
.PHONY: destroy-all
destroy-all: confirm-destroy \
	tf-destroy-dns-phase2 \
	k8s-delete \
	tf-destroy-dns-phase1 \
	tf-destroy-secrets \
	tf-destroy-rds \
	tf-destroy-eks \
	tf-destroy-network
	@echo "$(COLOR_GREEN)✓ All resources destroyed$(COLOR_RESET)"

# .PHONY: destroy-all
# destroy-all: confirm-destroy tf-destroy-dns-phase2 k8s-delete tf-destroy-dns-phase1 tf-destroy-secrets tf-destroy-rds tf-destroy-eks tf-destroy-network



# ============================================================================
# COST
# ============================================================================

.PHONY: cost-check
cost-check:
	@echo "EKS Clusters:"; aws eks list-clusters --query "clusters" --output table
	@echo "RDS:"; aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" --output table
	@echo "NAT:"; aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query "NatGateways[].NatGatewayId" --output table
	@echo "Secrets Manager (charged $$0.40/secret/month):"; aws secretsmanager list-secrets --query "SecretList[].Name" --output table