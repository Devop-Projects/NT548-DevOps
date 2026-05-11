# envs/eks/terraform.tfvars

project            = "devops"
environment        = "dev"
region             = "ap-southeast-1"
kubernetes_version = "1.30"

# ⚠️ Thay bằng IP của bạn (cho secure)
# Lấy IP: curl ifconfig.me
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # tạm thời

# Node group
node_instance_types = ["t3.medium", "t3a.medium"]
node_capacity_type  = "SPOT"
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2