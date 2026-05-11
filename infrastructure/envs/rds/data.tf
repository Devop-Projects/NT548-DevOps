# envs/rds/data.tf

# ─── Đọc network state ───────────────────────────
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "thesis-tfstate-954692413669" # ← Đổi
    key    = "dev/network/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# ─── Đọc EKS state (cần SG của workers) ──────────
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "thesis-tfstate-954692413669" # ← Đổi
    key    = "dev/eks/terraform.tfstate"
    region = "ap-southeast-1"
  }
}