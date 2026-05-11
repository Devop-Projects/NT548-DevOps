# envs/dns/acm.tf

# ─── ACM Certificate ─────────────────────────────
# Yêu cầu cert cho:
#   - app.example.com  (subdomain chính)
#   - *.example.com    (wildcard cho future subdomain)
resource "aws_acm_certificate" "main" {
  domain_name = var.domain_name   # apex domain

  subject_alternative_names = [
    "*.${var.domain_name}",        # wildcard
    local.full_fqdn,                # subdomain cụ thể
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true   # Tránh downtime khi rotate cert
  }

  tags = {
    Name = "${var.project}-cert"
  }
}

# ─── DNS validation records ──────────────────────
# ACM yêu cầu CNAME record để verify ownership
# Terraform tự tạo CNAME từ output của ACM
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# ─── ACM cert validation (đợi DNS propagate) ────
# Resource này không tạo gì, chỉ "đợi" cho ACM verify xong
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"   # Đôi khi DNS validation lâu
  }
}