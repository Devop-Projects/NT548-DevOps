# envs/eks/eks.tf
#
# EKS Cluster với Managed Node Group

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # ─── Cluster info ──────────────────────────────────
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  # ─── Network ───────────────────────────────────────
  # Đọc VPC ID + private subnet IDs từ network state
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  # ⚠️ Workers chạy ở PRIVATE subnet (best practice)

  # ─── API Server access ─────────────────────────────
  # Public access: cho phép kubectl từ máy bạn (cần whitelist IP)
  # Private access: từ trong VPC (vd: bastion host)
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # ─── EKS Addons ────────────────────────────────────
  # AWS quản lý hộ — tự update version, tích hợp CloudWatch
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      # Tăng số IP per ENI (default 1 IP/pod, max 740 pod/node)
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # ─── Managed Node Groups ───────────────────────────
  eks_managed_node_groups = {
    default = {
      # Naming
      name = "${local.cluster_name}-default"

      # Capacity
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Instance config
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type # SPOT for dev

      # Disk
      disk_size = 30 # GB EBS gp3

      # Labels (cho scheduler)
      labels = {
        role        = "general"
        environment = var.environment
      }

      # Taints (optional — limit pod được schedule)
      # taints = {
      #   spot = {
      #     key    = "spot"
      #     value  = "true"
      #     effect = "NO_SCHEDULE"
      #   }
      # }

      tags = local.common_tags
    }
  }

  # ─── Access (RBAC) ─────────────────────────────────
  # Mới (v20+): Access Entries thay aws-auth ConfigMap
  authentication_mode = "API_AND_CONFIG_MAP"

  # Auto grant cluster admin cho IAM identity tạo cluster
  # → Sau khi apply, kubectl get pods sẽ work ngay
  enable_cluster_creator_admin_permissions = true

  # ─── Cluster security ──────────────────────────────
  # Encryption at rest cho secret
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # ─── Logging ───────────────────────────────────────
  # Bật audit log cho compliance + debug
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  cloudwatch_log_group_retention_in_days = 7 # 7 ngày cho dev

  tags = local.common_tags
}

# ─── KMS key cho EKS secret encryption ─────────────
resource "aws_kms_key" "eks" {
  description             = "EKS secret encryption — ${local.cluster_name}"
  deletion_window_in_days = 7 # 7 ngày để recover nếu lỡ delete
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-encryption"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}-encryption"
  target_key_id = aws_kms_key.eks.key_id
}

# ─── IRSA cho EBS CSI Driver ───────────────────────
# Driver này mount EBS volume làm PV cho pod
# Cần IAM permission để CreateVolume, AttachVolume, ...
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}