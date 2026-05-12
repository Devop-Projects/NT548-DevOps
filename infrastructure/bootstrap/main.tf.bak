# bootstrap/main.tf
#
# Bootstrap: Tạo S3 bucket + DynamoDB table cho remote state
# Project này dùng LOCAL backend (state nhỏ, ít thay đổi)
# Sau khi tạo xong, các project khác sẽ dùng S3 backend này.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ⚠️ Bootstrap dùng LOCAL backend (không có sẵn S3 backend)
  # Sau khi tạo xong, KHÔNG migrate bootstrap sang S3
  # → Lý do: nếu S3 hỏng, vẫn có local state để rebuild
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "devops-thesis"
      Purpose   = "terraform-bootstrap"
      ManagedBy = "terraform"
      Critical  = "true" # ← marker: KHÔNG xóa nhầm
    }
  }
}

# ─── Account info ──────────────────────────────────────
data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "thesis-tfstate-${local.account_id}"
  table_name  = "thesis-tfstate-locks"
}

# ─── S3 Bucket cho state ───────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # ⚠️ LIFECYCLE: prevent accidental destroy
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State Storage"
  }
}

# Versioning — RẤT QUAN TRỌNG
# Nếu state corrupt, có thể rollback version cũ
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption — bảo vệ secret trong state
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3 (free)
      # Có thể đổi sang aws:kms với kms_master_key_id nếu cần audit chi tiết
    }
    bucket_key_enabled = true
  }
}

# Block public access — defense in depth
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy — clean up version cũ để tiết kiệm tiền
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {} # Apply cho mọi object

    noncurrent_version_expiration {
      noncurrent_days = 90 # Xóa version cũ > 90 ngày
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ─── DynamoDB cho state locking ────────────────────────
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST" # ← On-demand: free tier 25 RCU/WCU

  hash_key = "LockID" # ← Tên field BẮT BUỘC, Terraform expect

  attribute {
    name = "LockID"
    type = "S" # String
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Point-in-time recovery (free 35 ngày)
  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State Locks"
  }
}