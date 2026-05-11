# envs/dns/terraform.tfvars

project     = "devops-thesis"
environment = "dev"
region      = "ap-southeast-1"

# ⚠️ Đổi domain của bạn
domain_name = "vantai.click"
subdomain   = "task-manager"   # → app.vantai.click

# Tùy thuộc vào bạn:
# - true: nếu Hosted Zone CHƯA tồn tại
# - false: nếu zone đã có (vd: mua qua Route53 → auto-created)
create_hosted_zone = true