# envs/dev/terraform.tfvars
#
# Variable values cho môi trường dev
# ⚠️ KHÔNG commit nếu chứa secret. File này chỉ có config, OK commit.

project     = "devops-thesis"
environment = "dev"
region      = "ap-southeast-1"
owner       = "vantai"

vpc_cidr = "10.0.0.0/16"
az_count = 2

# Dev: 1 NAT cho tiết kiệm ($33/tháng vs $99/tháng)
single_nat_gateway = true