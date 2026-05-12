# envs/dns/variables.tf

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
  description = "S3 bucket name cho remote state lookup (đọc EKS state)"
  type        = string
}

variable "domain_name" {
  description = "Root domain (vd: example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain cho app (vd: app, api, task-manager)"
  type        = string
  default     = "app"
}

variable "create_hosted_zone" {
  description = "true nếu zone chưa tồn tại"
  type        = bool
  default     = false
}
