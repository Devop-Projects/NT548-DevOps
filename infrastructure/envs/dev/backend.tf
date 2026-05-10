# envs/dev/backend.tf
#
# Remote state config (từ Lesson 5.5)
# ⚠️ Thay bucket name = output từ bootstrap

terraform {
  backend "s3" {
    bucket         = "thesis-tfstate-954692413669" # ← Đổi account ID của bạn
    key            = "dev/network/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "thesis-tfstate-locks"
    encrypt        = true
  }
}