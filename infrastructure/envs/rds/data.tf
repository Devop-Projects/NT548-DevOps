# envs/rds/data.tf

# ─── Đọc network state ─────────────────────────────
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "${var.environment}/network/terraform.tfstate"
    region = var.region
  }
}

# ─── Đọc EKS state (cần SG node để RDS allow) ──────
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "${var.environment}/eks/terraform.tfstate"
    region = var.region
  }
}
