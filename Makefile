# ============================================================================
# NT548 Task Manager — DevOps Automation (v2.1 — bugfix state keys)
# ============================================================================
# Fix v2 → v2.1: folder name `dev` được map sang state key `network`
# để khớp với convention các remote_state lookup đã có.
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
# ⭐ FIX v2.1: tf_init nhận 2 tham số:
#   $(1) = folder name (dev, eks, rds, secrets, dns)
#   $(2) = state key   (network, eks, rds, secrets, dns)
# Lý do: folder "dev" chứa network code, nhưng state key phải là "network"
# để match với các data.terraform_remote_state.network.config.key lookup.

define tf_init
	@echo "$(COLOR_BLUE)▶ Init $(1) → key=$(ENVIRONMENT)/$(2)/terraform.tfstate ...$(COLOR_RESET)"
	@cd $(ENVS_DIR)/$(1) && \
		terraform init -reconfigure \
			-backend-config=../../backend-config.hcl \
			-backend-config="key=$(ENVIRONMENT)/$(2)/terraform.tfstate"
endef

.PHONY: tf-init-all
tf-init-all: setup-symlinks  ## Init tất cả states (folder → key mapping đúng)
	$(call tf_init,dev,network)
	$(call tf_init,eks,eks)
	$(call tf_init,rds,rds)
	$(call tf_init,secrets,secrets)
	$(call tf_init,dns,dns)
	@echo "$(COLOR_GREEN)✓ All states initialized$(COLOR_RESET)"

# ============================================================================
# TERRAFORM APPLY
# ============================================================================

.PHONY: tf-apply-network
tf-apply-network:  ## Apply network (folder=dev, key=dev/network/...)
	@cd $(ENVS_DIR)/dev && terraform apply -auto-approve

.PHONY: tf-apply-eks
tf-apply-eks:  ## Apply EKS (~15 min)
	@cd $(ENVS_DIR)/eks && terraform apply -auto-approve

.PHONY: tf-apply-rds
tf-apply-rds:  ## Apply RDS (~10 min)
	@cd $(ENVS_DIR)/rds && terraform apply -auto-approve

.PHONY: tf-apply-secrets
tf-apply-secrets:
	@cd $(ENVS_DIR)/secrets && terraform apply -auto-approve

.PHONY: tf-apply-infrastructure
tf-apply-infrastructure: tf-apply-network tf-apply-eks tf-apply-rds tf-apply-secrets

.PHONY: tf-apply-dns-phase1
tf-apply-dns-phase1:  ## Apply DNS phase 1: ACM + Hosted Zone, chưa lookup ALB
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

.PHONY: k8s-render
k8s-render:  ## Render K8s manifests từ TF outputs
	@echo "$(COLOR_BLUE)▶ Rendering manifests...$(COLOR_RESET)"
	@RDS_ENDPOINT=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_address) && \
	 RDS_SECRET_ARN=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_master_user_secret_arn) && \
	 RDS_SECRET_NAME=$$(echo $$RDS_SECRET_ARN | awk -F: '{print $$NF}' | sed 's/-[A-Za-z0-9]*$$//') && \
	 DB_NAME=$$(cd $(ENVS_DIR)/rds && terraform output -raw db_name) && \
	 ACM_CERT_ARN=$$(cd $(ENVS_DIR)/dns && terraform output -raw acm_certificate_arn 2>/dev/null | tr -d '\000-\010\013\014\016-\037' || echo "PENDING") && \
	 APP_FQDN=$$(cd $(ENVS_DIR)/dns && terraform output -raw full_fqdn 2>/dev/null | tr -d '\000-\010\013\014\016-\037' || echo "task-manager.example.com") && \
	 export RDS_ENDPOINT RDS_SECRET_NAME DB_NAME ACM_CERT_ARN APP_FQDN \
	        IMAGE_TAG="$(IMAGE_TAG)" DOCKERHUB_USER="$(DOCKERHUB_USER)" && \
	 echo "  RDS_ENDPOINT    = $$RDS_ENDPOINT" && \
	 echo "  RDS_SECRET_NAME = $$RDS_SECRET_NAME" && \
	 echo "  ACM_CERT_ARN    = $$ACM_CERT_ARN" && \
	 echo "  APP_FQDN        = $$APP_FQDN" && \
	 echo "  IMAGE_TAG       = $$IMAGE_TAG" && \
	 for tpl in $(K8S_OVERLAY)/*.tpl; do \
	   out=$${tpl%.tpl}; \
	   envsubst < $$tpl > $$out; \
	   echo "  ✓ $$out"; \
	 done
,
.PHONY: k8s-namespace
k8s-namespace:
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

.PHONY: k8s-jwt-secret
k8s-jwt-secret: k8s-namespace
	@if kubectl get secret backend-secrets -n $(NAMESPACE) >/dev/null 2>&1; then \
		echo "$(COLOR_YELLOW)⚠ backend-secrets exists$(COLOR_RESET)"; \
	else \
		JWT=$$(openssl rand -base64 48 | tr -d '\n'); \
		kubectl create secret generic backend-secrets --from-literal=JWT_SECRET="$$JWT" -n $(NAMESPACE); \
	fi

.PHONY: k8s-deploy
k8s-deploy: kubeconfig k8s-render k8s-jwt-secret
	@cd $(K8S_OVERLAY) && kubectl apply -k .
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
	@kubectl get pods,ingress,externalsecret -n $(NAMESPACE)

.PHONY: k8s-logs
k8s-logs:
	@kubectl logs -n $(NAMESPACE) -l app=backend --tail=50 -f

# ============================================================================
# END-TO-END
# ============================================================================

.PHONY: deploy-all
deploy-all: tf-init-all tf-apply-infrastructure tf-apply-dns-phase1 k8s-deploy k8s-wait-alb tf-apply-dns-phase2 k8s-render
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
# DESTROY
# ============================================================================

.PHONY: k8s-delete
k8s-delete:
	@cd $(K8S_OVERLAY) && kubectl delete -k . --ignore-not-found
	@kubectl delete secret backend-secrets -n $(NAMESPACE) --ignore-not-found
	@sleep 60

.PHONY: tf-destroy-dns-phase2
tf-destroy-dns-phase2:  ## Remove ALB DNS record before deleting K8s ALB
	@echo "$(COLOR_BLUE)▶ DNS Destroy Phase 2: remove ALB record$(COLOR_RESET)"
	@sed -i 's/alb_exists = true/alb_exists = false/g' $(ENVS_DIR)/dns/terraform.tfvars || true
	@cd $(ENVS_DIR)/dns && terraform apply -auto-approve

.PHONY: tf-destroy-dns-phase1
tf-destroy-dns-phase1:  ## Destroy DNS base resources after ALB record removed
	@echo "$(COLOR_BLUE)▶ DNS Destroy Phase 1: destroy ACM/zone$(COLOR_RESET)"
	@cd $(ENVS_DIR)/dns && terraform destroy -auto-approve

.PHONY: tf-destroy-secrets
tf-destroy-secrets:
	@cd $(ENVS_DIR)/secrets && terraform destroy -auto-approve

.PHONY: tf-destroy-rds
tf-destroy-rds:
	@cd $(ENVS_DIR)/rds && terraform destroy -auto-approve

.PHONY: tf-destroy-eks
tf-destroy-eks:
	@cd $(ENVS_DIR)/eks && terraform destroy -auto-approve

.PHONY: tf-destroy-network
tf-destroy-network:
	@cd $(ENVS_DIR)/dev && terraform destroy -auto-approve

.PHONY: destroy-all
destroy-all: confirm-destroy tf-destroy-dns-phase2 k8s-delete tf-destroy-dns-phase1 tf-destroy-secrets tf-destroy-rds tf-destroy-eks tf-destroy-network

.PHONY: confirm-destroy
confirm-destroy:
	@read -p "Type 'destroy' to confirm: " confirm; \
	if [ "$$confirm" != "destroy" ]; then exit 1; fi

# ============================================================================
# COST
# ============================================================================

.PHONY: cost-check
cost-check:
	@echo "EKS Clusters:"; aws eks list-clusters --query "clusters" --output table
	@echo "RDS:"; aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" --output table
	@echo "NAT:"; aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query "NatGateways[].NatGatewayId" --output table