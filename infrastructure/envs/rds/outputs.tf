# envs/rds/outputs.tf

# ─── Connection info (cho app) ───────────────────
output "db_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "RDS hostname only"
  value       = aws_db_instance.main.address
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_username" {
  value = aws_db_instance.main.username
}

# ─── Secrets Manager ─────────────────────────────
output "db_master_user_secret_arn" {
  description = "ARN của secret chứa master password (auto-generated)"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

# ─── Security ────────────────────────────────────
output "db_security_group_id" {
  value = aws_security_group.rds.id
}

# ─── KMS ─────────────────────────────────────────
output "db_kms_key_id" {
  value = aws_kms_key.rds.id
}