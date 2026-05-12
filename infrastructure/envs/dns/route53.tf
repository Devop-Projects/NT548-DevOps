# envs/dns/route53.tf
#
# ⭐ THAY ĐỔI CHÍNH so với version cũ:
# - cluster_name lấy ĐỘNG từ EKS remote state (không hardcode "devops-dev")
# - bucket cho remote state đọc từ var.tfstate_bucket
# - Naming local.cluster_name = "${project}-${environment}" để match EKS

# ─── Đọc EKS state để lấy cluster_name ───────────
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "${var.environment}/eks/terraform.tfstate"
    region = var.region
  }
}

# ─── Hosted Zone ─────────────────────────────────
data "aws_route53_zone" "main" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name = "${var.project}-zone"
  }
}

locals {
  zone_id   = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  full_fqdn = "${var.subdomain}.${var.domain_name}"

  # ⭐ Cluster name lấy động — match với EKS local.cluster_name = "${project}-${environment}"
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
}

# ─── ALB Lookup qua tag (AWS LB Controller tự gắn) ────
data "aws_lb" "app" {
  tags = {
    "elbv2.k8s.aws/cluster"    = local.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
  }
}

# ─── A record (ALIAS) ──────────────────────────────
resource "aws_route53_record" "app" {
  zone_id = local.zone_id
  name    = local.full_fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
