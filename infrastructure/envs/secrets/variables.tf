# envs/secrets/variables.tf

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

# Reserved cho consistency (secrets không đọc remote state khác)
variable "tfstate_bucket" {
  description = "S3 bucket name (unused ở secrets state)"
  type        = string
  default     = ""
}
