variable "project_name" { type = string }
variable "db_username"  { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_host"  { type = string }
variable "db_name"  { type = string }
variable "jwt_secret" {
  type      = string
  sensitive = true
}