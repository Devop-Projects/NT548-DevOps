output "db_url_secret_arn" { value = aws_secretsmanager_secret.db_url.arn }
output "jwt_secret_arn"    { value = aws_secretsmanager_secret.jwt.arn }