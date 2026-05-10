# envs/dev/locals.tf
#
# Local values = computed/derived values, không phải input
# Khác variable: variable = từ ngoài vào, local = tính trong code

locals {
  # Naming convention
  name_prefix = "${var.project}-${var.environment}"

  # ─── CIDR planning  ─────────────────
  # VPC: 10.0.0.0/16
  # Public:  10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
  # Private: 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  # DB:      10.0.20.0/24, 10.0.21.0/24, 10.0.22.0/24 
  #
  # cidrsubnet(prefix, newbits, netnum):
  #   cidrsubnet("10.0.0.0/16", 8, 1)  = "10.0.1.0/24"
  #   cidrsubnet("10.0.0.0/16", 8, 2)  = "10.0.2.0/24"
  #   cidrsubnet("10.0.0.0/16", 8, 10) = "10.0.10.0/24"

  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  # Tags chung cho VPC resources
  common_tags = {
    Component = "network"
    Layer     = "infrastructure"
  }
}