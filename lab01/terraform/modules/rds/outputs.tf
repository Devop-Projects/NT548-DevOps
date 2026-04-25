output "db_endpoint" { value = aws_db_instance.main.endpoint }
output "db_host"     { value = aws_db_instance.main.address }
output "db_port"     { value = aws_db_instance.main.port }
output "db_name"     { value = aws_db_instance.main.db_name }
output "database_url" {
  value     = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:5432/${var.db_name}"
  sensitive = true
}