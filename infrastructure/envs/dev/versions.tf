# envs/dev/versions.tf
#
# Tách versions ra file riêng = best practice
# Lý do: dễ tìm khi cần update, single source of truth

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}