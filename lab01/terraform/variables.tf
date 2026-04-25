variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "nt548-lab01"
}

variable "my_ip" {
  description = "IP cua ban de whitelist SSH. Lay tai https://checkip.amazonaws.com"
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_cidr_2" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.3.0/24"
}

variable "private_subnet_cidr_2" {
  type    = string
  default = "10.0.4.0/24"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  type = string
}

variable "app_port" {
  description = "Port app: 3000 (mono backend) hoac 80 (micro api-gateway)"
  type        = number
  default     = 3000
}

variable "db_name" {
  type    = string
  default = "taskdb"
}

variable "db_username" {
  type    = string
  default = "taskuser"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "container_image" {
  description = "Docker image URI"
  type        = string
  default     = "nginx:alpine"
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "jwt_secret" {
  description = "JWT secret — phai khop voi JWT_SECRET trong .env"
  type        = string
  sensitive   = true
}