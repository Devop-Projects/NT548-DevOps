# envs/eks/data.tf

# ─── Đọc network state qua var.tfstate_bucket (không hardcode) ───
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "${var.environment}/network/terraform.tfstate"
    region = var.region
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
