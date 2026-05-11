# envs/dev/vpc.tf
#
# VPC dùng module terraform-aws-modules/vpc/aws

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  # ─── Naming ────────────────────────────────────────
  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  # ─── AZ + Subnets ──────────────────────────────────
  # Slice lấy N AZ đầu tiên (vd: 2 AZ first)
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  # ─── NAT Gateway ───────────────────────────────────
  enable_nat_gateway = true                   # Cần NAT cho private → Internet
  single_nat_gateway = var.single_nat_gateway # Dev: 1 NAT, Prod: 1/AZ

  # ─── DNS settings (BẮT BUỘC cho EKS) ───────────────
  enable_dns_hostnames = true
  enable_dns_support   = true

  # ─── Subnet tags (BẮT BUỘC cho EKS Load Balancer auto-discovery) ───
  # Khi tạo Service type=LoadBalancer trên EKS:
  #   - AWS Load Balancer Controller tìm subnet có tag này
  #   - Public LB → tag "kubernetes.io/role/elb" = "1"
  #   - Internal LB → tag "kubernetes.io/role/internal-elb" = "1"
  # Không có tag này → LB không deploy được!
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    Tier                     = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    Tier                              = "private"
  }

  # ─── VPC Flow Logs (audit traffic — optional) ──────
  # Bật cho prod, tắt dev (tiết kiệm CloudWatch cost)
  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  # ─── Tags ──────────────────────────────────────────
  tags = local.common_tags
}