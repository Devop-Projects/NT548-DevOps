# ============================================================================
# NT548 Task Manager — DevOps Automation
# ============================================================================
# Usage:
#   make help              List all targets
#   make tf-apply-all      Apply all Terraform states in order
#   make k8s-deploy        Deploy K8s app to EKS
#   make destroy-all       Destroy entire stack (CAREFUL!)
# ============================================================================

# Color codes for output
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
INFRA_DIR     := infrastructure/envs
K8S_OVERLAY   := k8s/overlays/aws

# Get dynamic values from Terraform (cached)
DOCKERHUB_USER ?= doanvantai
IMAGE_TAG      ?= $(shell git rev-parse --short origin/main 2>/dev/null || echo "latest")

.PHONY: help
help:  ## Show this help
	@echo "$(COLOR_BLUE)NT548 Task Manager — Available targets$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?##.*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-25s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""

# ============================================================================
# TERRAFORM TARGETS
# ============================================================================

.PHONY: tf-init-all
tf-init-all:  ## Init all Terraform states
	@echo "$(COLOR_BLUE)▶ Initializing Terraform states...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/dev && terraform init -upgrade
	@cd $(INFRA_DIR)/eks && terraform init -upgrade
	@cd $(INFRA_DIR)/rds && terraform init -upgrade
	@cd $(INFRA_DIR)/dns && terraform init -upgrade
	@echo "$(COLOR_GREEN)✓ All Terraform states initialized$(COLOR_RESET)"

.PHONY: tf-apply-network
tf-apply-network:  ## Apply network state (VPC)
	@echo "$(COLOR_BLUE)▶ Applying network state...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/dev && terraform apply -auto-approve

.PHONY: tf-apply-eks
tf-apply-eks:  ## Apply EKS state (cluster + addons)
	@echo "$(COLOR_BLUE)▶ Applying EKS state (takes ~15 min)...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/eks && terraform apply -auto-approve

.PHONY: tf-apply-rds
tf-apply-rds:  ## Apply RDS state (database)
	@echo "$(COLOR_BLUE)▶ Applying RDS state (takes ~10 min)...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/rds && terraform apply -auto-approve

.PHONY: tf-apply-dns
tf-apply-dns:  ## Apply DNS state (Route53 + ACM)
	@echo "$(COLOR_BLUE)▶ Applying DNS state...$(COLOR_RESET)"
	@cd $(INFRA_DIR)/dns && terraform apply -auto-approve

.PHONY: tf-apply-all
tf-apply-all: tf-apply-network tf-apply-eks tf-apply-rds tf-apply-dns  ## Apply all states in order
	@echo "$(COLOR_GREEN)✓ All Terraform states applied$(COLOR_RESET)"

# ============================================================================
# KUBERNETES TARGETS
# ============================================================================

.PHONY: kubeconfig
kubeconfig:  ## Update kubectl context for EKS
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	@echo "$(COLOR_GREEN)✓ kubeconfig updated$(COLOR_RESET)"

.PHONY: k8s-namespace
k8s-namespace:  ## Create namespace
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

.PHONY: k8s-jwt-secret
k8s-jwt-secret: k8s-namespace  ## Generate JWT secret (idempotent)
	@if kubectl get secret backend-secrets -n $(NAMESPACE) >/dev/null 2>&1; then \
		echo "$(COLOR_YELLOW)⚠ backend-secrets already exists — skipping$(COLOR_RESET)"; \
	else \
		JWT=$$(openssl rand -base64 48 | tr -d '\n'); \
		kubectl create secret generic backend-secrets \
			--from-literal=JWT_SECRET="$$JWT" \
			-n $(NAMESPACE); \
		echo "$(COLOR_GREEN)✓ backend-secrets created$(COLOR_RESET)"; \
	fi

.PHONY: k8s-update-tags
k8s-update-tags:  ## Update image tags in kustomization
	@echo "$(COLOR_BLUE)▶ Updating image tags to $(IMAGE_TAG)...$(COLOR_RESET)"
	@cd $(K8S_OVERLAY) && \
		sed -i "s|newTag: .*|newTag: $(IMAGE_TAG)|g" kustomization.yaml && \
		sed -i "s|nt548-backend:.*|nt548-backend:$(IMAGE_TAG)|g" *patch.yaml && \
		sed -i "s|nt548-frontend:.*|nt548-frontend:$(IMAGE_TAG)|g" *patch.yaml
	@echo "$(COLOR_GREEN)✓ Image tags updated$(COLOR_RESET)"

.PHONY: k8s-deploy
k8s-deploy: kubeconfig k8s-jwt-secret k8s-update-tags  ## Deploy K8s manifests
	@echo "$(COLOR_BLUE)▶ Deploying app to EKS...$(COLOR_RESET)"
	@cd $(K8S_OVERLAY) && kubectl apply -k .
	@echo "$(COLOR_BLUE)▶ Waiting for pods to be ready...$(COLOR_RESET)"
	@kubectl wait --for=condition=Ready pod -l app=backend -n $(NAMESPACE) --timeout=300s
	@kubectl wait --for=condition=Ready pod -l app=frontend -n $(NAMESPACE) --timeout=300s
	@echo "$(COLOR_GREEN)✓ Deployment complete$(COLOR_RESET)"

.PHONY: k8s-status
k8s-status:  ## Show K8s deployment status
	@echo "$(COLOR_BLUE)═══ Pods ═══$(COLOR_RESET)"
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "$(COLOR_BLUE)═══ Services ═══$(COLOR_RESET)"
	@kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "$(COLOR_BLUE)═══ Ingress (ALB) ═══$(COLOR_RESET)"
	@kubectl get ingress -n $(NAMESPACE)
	@echo ""
	@echo "$(COLOR_BLUE)═══ External Secret ═══$(COLOR_RESET)"
	@kubectl get externalsecret -n $(NAMESPACE)

.PHONY: k8s-logs
k8s-logs:  ## Tail backend logs
	@kubectl logs -n $(NAMESPACE) -l app=backend --tail=50 -f

.PHONY: k8s-restart
k8s-restart:  ## Restart all deployments (pickup new image/secrets)
	@kubectl rollout restart deployment/backend deployment/frontend -n $(NAMESPACE)
	@echo "$(COLOR_GREEN)✓ Restart triggered$(COLOR_RESET)"

# ============================================================================
# END-TO-END TARGETS
# ============================================================================

.PHONY: deploy-all
deploy-all: tf-apply-all k8s-deploy verify  ## Deploy entire stack from scratch
	@echo "$(COLOR_GREEN)═══════════════════════════════════════════════$(COLOR_RESET)"
	@echo "$(COLOR_GREEN)  ✅ Full stack deployed successfully$(COLOR_RESET)"
	@echo "$(COLOR_GREEN)═══════════════════════════════════════════════$(COLOR_RESET)"

.PHONY: verify
verify:  ## Verify end-to-end health
	@DOMAIN=$$(cd $(INFRA_DIR)/dns && terraform output -raw full_fqdn); \
	echo "$(COLOR_BLUE)▶ Testing https://$$DOMAIN ...$(COLOR_RESET)"; \
	STATUS=$$(curl -s -o /dev/null -w "%{http_code}" https://$$DOMAIN/api/health/ready); \
	if [ "$$STATUS" = "200" ]; then \
		echo "$(COLOR_GREEN)✓ HTTP $$STATUS — App is healthy$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_RED)✗ HTTP $$STATUS — App not ready$(COLOR_RESET)"; \
	fi

# ============================================================================
# DESTROY TARGETS (CAREFUL!)
# ============================================================================

.PHONY: k8s-delete
k8s-delete:  ## Delete K8s resources (keeps cluster)
	@echo "$(COLOR_YELLOW)⚠ Deleting K8s resources...$(COLOR_RESET)"
	@cd $(K8S_OVERLAY) && kubectl delete -k . --ignore-not-found
	@kubectl delete secret backend-secrets -n $(NAMESPACE) --ignore-not-found
	@echo "$(COLOR_GREEN)✓ K8s resources deleted (ALB auto-destroy in ~2 min)$(COLOR_RESET)"

.PHONY: tf-destroy-dns
tf-destroy-dns:  ## Destroy DNS state
	@cd $(INFRA_DIR)/dns && terraform destroy -auto-approve

.PHONY: tf-destroy-rds
tf-destroy-rds:  ## Destroy RDS state
	@cd $(INFRA_DIR)/rds && terraform destroy -auto-approve

.PHONY: tf-destroy-eks
tf-destroy-eks:  ## Destroy EKS state
	@cd $(INFRA_DIR)/eks && terraform destroy -auto-approve

.PHONY: tf-destroy-network
tf-destroy-network:  ## Destroy network state (LAST)
	@cd $(INFRA_DIR)/dev && terraform destroy -auto-approve

.PHONY: destroy-all
destroy-all: confirm-destroy k8s-delete tf-destroy-dns tf-destroy-rds tf-destroy-eks tf-destroy-network  ## DESTROY EVERYTHING
	@echo "$(COLOR_GREEN)✓ All resources destroyed$(COLOR_RESET)"

.PHONY: confirm-destroy
confirm-destroy:
	@echo "$(COLOR_RED)⚠ This will DESTROY all infrastructure!$(COLOR_RESET)"
	@read -p "Type 'destroy' to confirm: " confirm; \
	if [ "$$confirm" != "destroy" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi

# ============================================================================
# COST CHECK
# ============================================================================

.PHONY: cost-check
cost-check:  ## Check active AWS resources (costs)
	@echo "$(COLOR_BLUE)═══ Cost-incurring resources ═══$(COLOR_RESET)"
	@echo ""
	@echo "EKS Clusters:"
	@aws eks list-clusters --query "clusters" --output table
	@echo ""
	@echo "RDS Instances:"
	@aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" --output table
	@echo ""
	@echo "ALB Load Balancers:"
	@aws elbv2 describe-load-balancers --query "LoadBalancers[].[LoadBalancerName,State.Code]" --output table
	@echo ""
	@echo "NAT Gateways (active):"
	@aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query "NatGateways[].NatGatewayId" --output table

