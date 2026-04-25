variable "project_name"       { type = string }
variable "aws_region"         { type = string }
variable "ecs_sg_id"           { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "target_group_arn"    { type = string }
variable "listener_arn"         { type = string }
variable "container_image"     { type = string }
variable "container_port" {
  type        = number
  description = "Port container lang nghe: mono=3000, micro api-gateway=80"
  default     = 3000
}
variable "db_host"             { type = string }
variable "db_name"             { type = string }
variable "db_username"         { type = string }
variable "db_url_secret_arn"   { type = string }
variable "jwt_secret_arn"      { type = string }
variable "secret_arns"         { type = list(string) }
variable "desired_count" {
  type    = number
  default = 1
}