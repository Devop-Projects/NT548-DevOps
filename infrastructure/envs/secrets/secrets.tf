# envs/secrets/secrets.tf
#
# Backend application secrets

# ─── Random passwords ──────────────────────────
resource "random_password" "jwt_secret" {
  length  = 64
  special = true

  # Avoid characters problematic in URL/JSON
  override_special = "!@#$%^&*()-_=+[]{}"
}

resource "random_password" "jwt_refresh_secret" {
  length           = 64
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}"
}

# ─── Backend secrets (JSON structured) ─────────
resource "aws_secretsmanager_secret" "backend" {
  name        = "${var.project}/${var.environment}/backend/secrets"
  description = "Backend application secrets (JWT, etc.)"

  kms_key_id = aws_kms_key.secrets.arn # ← Custom KMS key

  # Recovery window: 7-30 ngày, có thể restore
  recovery_window_in_days = 7

  tags = {
    Component = "backend"
  }
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id

  # JSON structure: 1 secret = nhiều keys
  secret_string = jsonencode({
    JWT_SECRET         = random_password.jwt_secret.result
    JWT_REFRESH_SECRET = random_password.jwt_refresh_secret.result
    JWT_EXPIRES_IN     = "7d" # Non-sensitive, but kept here for cohesion
  })

  # Lifecycle: nếu generate password mới → tạo version mới (không destroy)
  lifecycle {
    ignore_changes = [secret_string]
    # Sau khi create lần đầu, KHÔNG auto-update khi random_password đổi
    # Muốn rotate: terraform taint random_password.jwt_secret + apply
  }
}

# ─── Output ────────────────────────────────────
output "backend_secret_arn" {
  description = "ARN cho ESO ExternalSecret reference"
  value       = aws_secretsmanager_secret.backend.arn
}

output "backend_secret_name" {
  description = "Name cho ESO key field"
  value       = aws_secretsmanager_secret.backend.name
}

output "kms_key_arn" {
  value = aws_kms_key.secrets.arn
}

output "kms_key_alias" {
  value = aws_kms_alias.secrets.name
}