# envs/dev/terraform.tfvars
#
# Chỉ chứa vars RIÊNG cho network state.
# Vars chung (project, environment, region, owner, tfstate_bucket)
# đã ở common.auto.tfvars (symlink → ../../common.tfvars).

vpc_cidr           = "10.0.0.0/16"
az_count           = 2
single_nat_gateway = true # Dev: 1 NAT cho tiết kiệm
