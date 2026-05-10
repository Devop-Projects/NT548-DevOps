# envs/dev/outputs.tf

# ─── VPC ──────────────────────────────────────────────
output "vpc_id" {
  description = "ID của VPC (dùng cho EKS, RDS sau)"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR của VPC"
  value       = module.vpc.vpc_cidr_block
}

# ─── Subnets ─────────────────────────────────────────
output "public_subnet_ids" {
  description = "List public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List private subnet IDs (dùng cho EKS workers)"
  value       = module.vpc.private_subnets
}

# ─── NAT ──────────────────────────────────────────────
output "nat_public_ips" {
  description = "Public IP của NAT Gateway (whitelist nếu cần)"
  value       = module.vpc.nat_public_ips
}

# ─── AZ ───────────────────────────────────────────────
output "azs" {
  description = "AZ đã sử dụng"
  value       = module.vpc.azs
}

# ─── Account info ─────────────────────────────────────
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}