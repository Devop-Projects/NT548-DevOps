variable "aws_region" {
  description = "AWS region de deploy (ap-southeast-1 = Singapore, gan VN nhat)"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tien to dat ten cho tat ca resources, de tim tren AWS Console"
  type        = string
  default     = "nt548-lab01"
}

variable "vpc_cidr" {
  description = "CIDR block cua VPC — 10.0.0.0/16 cho phep 65536 dia chi IP"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR cua Public Subnet — /24 = 256 dia chi"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR cua Private Subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "Loai EC2 instance — t2.micro nam trong Free Tier"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Ten EC2 Key Pair da tao tren AWS Console (de SSH vao may)"
  type        = string
}