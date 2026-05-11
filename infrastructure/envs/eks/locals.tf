# envs/eks/locals.tf

locals {
  cluster_name = "${var.project}-${var.environment}"

  common_tags = {
    Component = "eks"
  }
}