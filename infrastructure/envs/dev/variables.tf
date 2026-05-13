# envs/dev/variables.tf

variable "project" {
  description = "Project name"
  type        = string
  default     = "devops"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "owner" {
  description = "Resource owner (cho tag audit)"
  type        = string
}

# Reserved cho consistency với các state khác (network không đọc remote state)
variable "tfstate_bucket" {
  description = "S3 bucket name cho remote state (unused ở network state)"
  type        = string
  default     = ""
}

# ─── VPC config ───────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR."
  }
}

variable "az_count" {
  description = "Số AZ sử dụng (2-3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count phải 2 hoặc 3."
  }
}

variable "single_nat_gateway" {
  description = "Single NAT cho dev (tiết kiệm) hay 1 NAT/AZ cho prod"
  type        = bool
  default     = true
}
