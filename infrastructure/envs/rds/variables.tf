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

# ─── RDS Engine ──────────────────────────────────
variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres" # ← Đổi từ mysql
}

variable "db_engine_version" {
  description = "Engine version"
  type        = string
  default     = "15.7" # PostgreSQL 15.7 — kiểm tra latest tại apply time

  # Why 15.7?
  # - PostgreSQL 15 là LTS, support đến 2027
  # - 15.7 stable hơn 16.x (mới release)
  # - Sequelize 6.37+ support tốt PostgreSQL 15
}

variable "db_instance_class" {
  description = "Instance type (compute)"
  type        = string
  default     = "db.t3.micro" # Free tier eligible 12 tháng
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432 # PostgreSQL default (MySQL: 3306)
}

variable "db_allocated_storage" {
  description = "Storage GB (initial)"
  type        = number
  default     = 20
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
  description = "Master username (KHÔNG dùng 'admin' với PostgreSQL — reserved!)"
  type        = string
  default     = "appuser"

  validation {
    condition     = !contains(["admin", "user", "postgres", "root"], var.db_username)
    error_message = "Không dùng reserved username (admin/user/postgres/root) — PostgreSQL sẽ reject."
  }
}

variable "db_multi_az" {
  description = "Multi-AZ deployment"
  type        = bool
  default     = false # Dev: false. Prod: true.
}

variable "db_backup_retention_period" {
  description = "Số ngày giữ backup"
  type        = number
  default     = 1
}