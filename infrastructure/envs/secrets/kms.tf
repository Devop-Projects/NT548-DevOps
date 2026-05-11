# envs/secrets/kms.tf
#
# KMS key cho secrets encryption
# Pattern: 1 KMS key per "blast radius" (secrets, RDS, EKS riêng nhau)

resource "aws_kms_key" "secrets" {
  description             = "Encryption key for application secrets"
  deletion_window_in_days = 7    # 7-30 ngày để recover
  enable_key_rotation     = true # Rotate yearly automatic

  # Policy: ai dùng được key
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Account root cần full access (best practice)
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
    ]
  })

  tags = {
    Name = "${var.project}-secrets-encryption"
  }
}

# Friendly alias (vd: alias/devops-thesis-secrets)
resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

data "aws_caller_identity" "current" {}