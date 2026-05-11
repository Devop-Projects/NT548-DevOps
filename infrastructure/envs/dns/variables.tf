# envs/dns/variables.tf

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

variable "domain_name" {
  description = "Root domain (vd: example.com)"
  type        = string
  # KHÔNG default — bắt buộc nhập
}

variable "subdomain" {
  description = "Subdomain cho app (vd: app, api, www)"
  type        = string
  default     = "app"
}

# Quyết định tạo Hosted Zone mới hay dùng zone đã có?
variable "create_hosted_zone" {
  description = "true nếu zone chưa tồn tại"
  type        = bool
  default     = true
}