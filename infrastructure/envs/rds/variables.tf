# envs/rds/variables.tf

# ─── Common ──────────────────────────────────────
variable "project" {
  type    = string
  default = "devops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "owner" {
  type    = string
  default = "vantai"
}

variable "tfstate_bucket" {
  description = "S3 bucket name cho remote state lookup"
  type        = string
}

# ─── RDS Engine ──────────────────────────────────
variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "15.7"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"

  validation {
    condition     = !contains(["admin", "user", "postgres", "root"], var.db_username)
    error_message = "Không dùng reserved username (admin/user/postgres/root) — PostgreSQL sẽ reject."
  }
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_period" {
  type    = number
  default = 1
}
