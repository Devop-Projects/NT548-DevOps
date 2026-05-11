# envs/rds/backend.tf

terraform {
  backend "s3" {
    bucket         = "thesis-tfstate-954692413669" # ← Đổi account ID
    key            = "dev/rds/terraform.tfstate"   # ← Khác EKS!
    region         = "ap-southeast-1"
    dynamodb_table = "thesis-tfstate-locks"
    encrypt        = true
  }
}