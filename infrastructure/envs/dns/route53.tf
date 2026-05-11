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