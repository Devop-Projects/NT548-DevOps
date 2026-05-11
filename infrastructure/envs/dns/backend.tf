# envs/dns/backend.tf

terraform {
  backend "s3" {
    bucket         = "thesis-tfstate-954692413669"
    key            = "dev/dns/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "thesis-tfstate-locks"
    encrypt        = true
  }
}