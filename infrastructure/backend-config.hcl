# infrastructure/backend-config.hcl
#
# Single Source of Truth cho S3 backend.
# Mỗi state init với:
#   terraform init -reconfigure \
#     -backend-config=../../backend-config.hcl \
#     -backend-config="key=<env>/<component>/terraform.tfstate"
#
# Khi đổi account/region: CHỈ sửa file này, không sửa 8 file backend.tf.

bucket         = "thesis-tfstate-954692413669"
region         = "ap-southeast-1"
dynamodb_table = "thesis-tfstate-locks"
encrypt        = true
