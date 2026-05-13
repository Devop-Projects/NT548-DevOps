# envs/eks/terraform.tfvars
#
# Vars chung ở common.auto.tfvars (symlink). File này chỉ vars riêng EKS.

kubernetes_version = "1.30"

# ⚠️ Thay bằng IP của bạn cho secure (lấy: curl ifconfig.me)
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

# Node group
node_instance_types = ["t3.medium", "t3a.medium"]
node_capacity_type  = "SPOT"
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2
