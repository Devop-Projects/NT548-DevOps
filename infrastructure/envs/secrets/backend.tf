# envs/secrets/backend.tf
terraform {
  backend "s3" {
    bucket         = "thesis-tfstate-954692413669" # ← Đổi
    key            = "dev/secrets/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "thesis-tfstate-locks"
    encrypt        = true
  }
}