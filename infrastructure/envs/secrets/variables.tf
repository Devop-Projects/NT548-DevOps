# envs/secrets/variables.tf
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