# envs/eks/outputs.tf

# ─── Cluster ──────────────────────────────────────
output "cluster_name" {
  description = "EKS cluster name (cho update-kubeconfig)"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

# ─── IAM ──────────────────────────────────────────
output "cluster_iam_role_arn" {
  value = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  value = module.eks.eks_managed_node_groups.default.iam_role_arn
}

# ─── Security Groups ──────────────────────────────
output "cluster_security_group_id" {
  description = "SG mặc định của cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "SG của worker nodes (RDS sẽ allow SG này!)"
  value       = module.eks.node_security_group_id
}

# ─── OIDC (cho IRSA) ──────────────────────────────
output "oidc_provider_arn" {
  description = "ARN của OIDC provider — cho tạo IRSA roles sau"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

# ─── kubectl command tiện lợi ─────────────────────
output "configure_kubectl" {
  description = "Run lệnh này để configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}