# envs/eks/addons.tf
#
# Cluster-level addons (chạy trên EKS cluster):
# 1. AWS Load Balancer Controller — tạo ALB từ Ingress
# 2. External Secrets Operator — sync AWS Secrets Manager → K8s Secret
#
# Why đặt ở EKS state mà không phải state riêng?
# - Addons có lifecycle gắn chặt với cluster (cluster destroyed → addons gone)
# - Tránh circular dependency (addon state cần EKS, nhưng EKS không cần addon)
# - Single source of truth cho cluster

# ============================================================
# PART A: AWS LOAD BALANCER CONTROLLER
# ============================================================

# ─── IRSA Role cho AWS LB Controller ─────────────
# Controller cần IAM permissions:
#   - DescribeVpcs, DescribeSubnets
#   - CreateLoadBalancer, ModifyLoadBalancer, DeleteLoadBalancer
#   - CreateTargetGroup, ModifyTargetGroup
#   - CreateListener, ModifyListener
#   - AddTags, RemoveTags
#   - ACM, WAF, Shield (optional)
#
# Module này có pre-built policy chuẩn AWS recommendation
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${local.cluster_name}-aws-lbc"
  attach_load_balancer_controller_policy = true # Pre-built policy

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      # ⚠️ namespace_service_accounts: chỉ SA này được assume role
      # Format: "namespace:serviceaccount-name"
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

# ─── Helm release: AWS LB Controller ─────────────
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1" # Check latest at https://github.com/aws/eks-charts

  depends_on = [module.eks]

  wait             = true
  wait_for_jobs    = true
  timeout          = 300   # 5 phút

  # Cluster name (controller cần để tag resources)
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  # ServiceAccount với IRSA annotation
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # ⚠️ Annotation này KEY — gắn IAM role vào SA
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa.iam_role_arn
  }

  # Region (controller cần để gọi đúng AWS endpoint)
  set {
    name  = "region"
    value = var.region
  }

  # VPC ID (controller verify ALB cùng VPC)
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.network.outputs.vpc_id
  }

  # HA — 2 replicas để chịu node failure
  set {
    name  = "replicaCount"
    value = "2"
  }

  # Disable webhook cert generation (Helm chart tự handle)
  # Nếu lỗi webhook → set enableServiceMutatorWebhook = false
}

# ============================================================
# PART B: EXTERNAL SECRETS OPERATOR
# ============================================================

# ─── IAM Policy cho ESO ──────────────────────────
# ESO cần đọc Secrets Manager + decrypt KMS
data "aws_caller_identity" "addons" {}

resource "aws_iam_policy" "external_secrets" {
  name        = "${local.cluster_name}-external-secrets"
  description = "Allow External Secrets Operator to read Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
        ]
        # Narrow scope: chỉ RDS-managed secrets
        # Pattern: rds!cluster-* hoặc rds!db-*
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.addons.account_id}:secret:devops/*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.addons.account_id}:secret:rds!*",
        ]
      },
      {
        Sid      = "DecryptKMS"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          # Chỉ decrypt qua Secrets Manager service (defense in depth)
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = local.common_tags
}

# ─── IRSA Role cho ESO ───────────────────────────
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${local.cluster_name}-external-secrets"

  role_policy_arns = {
    secrets = aws_iam_policy.external_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = local.common_tags
}

# ─── Helm release: External Secrets Operator ─────
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.10.0"

  #  THÊM: phụ thuộc LBC đã hoàn toàn ready
  depends_on = [
    module.eks,
    helm_release.aws_load_balancer_controller,   # ← key fix
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  # Install CRDs (ExternalSecret, SecretStore, ...)
  set {
    name  = "installCRDs"
    value = "true"
  }

  # ServiceAccount với IRSA
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_secrets_irsa.iam_role_arn
  }
}