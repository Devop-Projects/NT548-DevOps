resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${var.project_name}/database-url"
  description             = "PostgreSQL connection string cho app"
  recovery_window_in_days = 0

  tags = { Name = "${var.project_name}-db-url-secret" }
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = "postgres://${var.db_username}:${var.db_password}@${var.db_host}:5432/${var.db_name}"
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.project_name}/jwt-secret"
  description             = "JWT signing secret"
  recovery_window_in_days = 0

  tags = { Name = "${var.project_name}-jwt-secret" }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = var.jwt_secret
}