# envs/dev/data.tf
#
# Data sources = đọc thông tin từ AWS (read-only)

# Lấy danh sách AZ available trong region
data "aws_availability_zones" "available" {
  state = "available"

  # Exclude AZ "Local Zones" hoặc "Wavelength Zones"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Account ID hiện tại (có thể dùng cho tag, ARN)
data "aws_caller_identity" "current" {}