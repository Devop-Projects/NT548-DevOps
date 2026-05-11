# envs/eks/data.tf

# ─── Đọc output từ network state \ ──────
# Đây là cách share data giữa các state đã tách
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "thesis-tfstate-954692413669" # ← Đổi account ID
    key    = "dev/network/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_caller_identity" "current" {}