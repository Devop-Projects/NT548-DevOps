# envs/dev/providers.tf
#
# Provider config tách riêng = clean

provider "aws" {
  region = var.region

  # ─── Default tags áp dụng cho MỌI resource ───
  # Best practice từ Lesson 5.1: cost allocation + audit
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Repository  = "github.com/vantai13/nt548-devops"
      CostCenter  = "thesis"
    }
  }
}