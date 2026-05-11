# envs/dns/providers.tf

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "dns"
    }
  }
}

# ⚠️ Nếu cần cert cho CloudFront (us-east-1)
# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1"
# }