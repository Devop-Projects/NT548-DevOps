# envs/dns/route53.tf

# ─── Hosted Zone ─────────────────────────────────
# Có 2 trường hợp:
# 1. Zone đã tồn tại (vd: mua domain qua Route53 → tự tạo zone)
#    → Dùng data source để đọc
# 2. Zone chưa có
#    → Tạo bằng resource

# ─── Trường hợp 1: Đọc zone existing ─────────────
data "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

# ─── Trường hợp 2: Tạo zone mới ──────────────────
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = {
    Name = "${var.project}-zone"
  }
}

# ─── Local: zone_id (lấy từ 1 trong 2 trường hợp) ─
locals {
  zone_id   = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  full_fqdn = "${var.subdomain}.${var.domain_name}"
}

# ─── A record (ALIAS) cho subdomain task-manager ─────
# Trỏ đến ALB tạo bởi K8s Ingress (AWS LB Controller).
#
# Pattern: dùng data source để lookup ALB qua tags
# Lý do: ALB DNS thay đổi mỗi lần recreate, không hardcode được
#
# Tag matching:
#   "elbv2.k8s.aws/cluster" = "<cluster-name>"
#   "ingress.k8s.aws/resource" = "LoadBalancer"
# → AWS LB Controller tự gắn các tag này khi tạo ALB từ Ingress
data "aws_lb" "app" {
  tags = {
    "elbv2.k8s.aws/cluster"    = "devops-dev" # ⚠️ Match cluster name của bạn
    "ingress.k8s.aws/resource" = "LoadBalancer"
  }
}

resource "aws_route53_record" "app" {
  zone_id = local.zone_id
  name    = local.full_fqdn # task-manager.vantai.click
  type    = "A"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id # ALB's canonical zone
    evaluate_target_health = true                    # Health check toàn ALB
  }
}