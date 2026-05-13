# infrastructure/common.tfvars
#
# Project-wide variables shared across ALL Terraform states.
# Mỗi state symlink: common.auto.tfvars -> ../../common.tfvars
# Terraform tự load file `*.auto.tfvars` → mọi state thấy chung biến.
#
# Khi cần deploy multi-env: COPY file này thành common-prod.tfvars rồi đổi.

project        = "devops"
environment    = "dev"
region         = "ap-southeast-1"
owner          = "vantai"

# Cho remote_state lookup (đọc state của state khác)
tfstate_bucket = "thesis-tfstate-954692413669"
