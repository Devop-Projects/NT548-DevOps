variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_port" {
  type        = number
  description = "Port container lang nghe: mono=3000, micro api-gateway=80"
  default     = 3000
}