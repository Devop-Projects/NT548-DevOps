# envs/eks/backend.tf

terraform {
  backend "s3" {
    bucket         = "thesis-tfstate-954692413669" # ← Đổi account ID
    key            = "dev/eks/terraform.tfstate"   # ← Khác network!
    region         = "ap-southeast-1"
    dynamodb_table = "thesis-tfstate-locks"
    encrypt        = true
  }
}