# envs/rds/variables.tf

# ─── Common ──────────────────────────────────────
variable "project" {
  type    = string
  default = "devops-thesis"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

# ─── RDS ─────────────────────────────────────────
variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Engine version"
  type        = string
  default     = "8.0.39" # MySQL 8.0 — kiểm tra latest tại apply time
}

variable "db_instance_class" {
  description = "Instance type (compute)"
  type        = string
  default     = "db.t3.micro" # Free tier eligible 12 tháng
}

variable "db_allocated_storage" {
  description = "Storage GB (initial)"
  type        = number
  default     = 20 # Free tier: 20GB
}

variable "db_max_allocated_storage" {
  description = "Max storage cho auto-scaling"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name (initial DB tạo trong instance)"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "admin"
}

variable "db_multi_az" {
  description = "Multi-AZ deployment"
  type        = bool
  default     = false # Dev: false. Prod: true.
}

variable "db_backup_retention_period" {
  description = "Số ngày giữ backup"
  type        = number
  default     = 1 # Dev: 1 ngày. Prod: 7-30.
}