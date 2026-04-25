variable "project_name"     { type = string }
variable "rds_sg_id"        { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_name"          { type = string }
variable "db_username"      { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}