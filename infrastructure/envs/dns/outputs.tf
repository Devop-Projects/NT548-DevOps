# envs/dns/outputs.tf

# ─── Domain ──────────────────────────────────────
output "domain_name" {
  description = "Root domain"
  value       = var.domain_name
}

output "full_fqdn" {
  description = "Full app URL (subdomain.domain)"
  value       = local.full_fqdn
}

# ─── Route53 ─────────────────────────────────────
output "hosted_zone_id" {
  description = "Hosted zone ID (cho A record của app)"
  value       = local.zone_id
}

output "name_servers" {
  description = "Nameservers (delegate domain registrar nếu cần)"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : data.aws_route53_zone.main[0].name_servers
}

# ─── ACM ─────────────────────────────────────────
output "acm_certificate_arn" {
  description = "ARN của cert (cho ALB)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "acm_status" {
  value = aws_acm_certificate.main.status
}
output "app_dns_record" {
  value = var.alb_exists ? aws_route53_record.app[0].fqdn : "not-created-yet"
}

output "app_alb_dns" {
  value = var.alb_exists ? data.aws_lb.app[0].dns_name : "not-created-yet"
}