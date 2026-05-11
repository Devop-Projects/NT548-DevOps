# bootstrap/outputs.tf
output "state_bucket_name" {
  description = "Tên S3 bucket cho remote state"
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.tfstate.arn
}

output "lock_table_name" {
  description = "Tên DynamoDB table cho lock"
  value       = aws_dynamodb_table.tfstate_lock.name
}

# In ra config sẵn sàng copy vào project khác
output "backend_config_snippet" {
  description = "Copy đoạn này vào project khác"
  value       = <<-EOT
  
  terraform {
    backend "s3" {
      bucket         = "${aws_s3_bucket.tfstate.id}"
      key            = "<env>/<component>/terraform.tfstate"
      region         = "${var.region}"
      dynamodb_table = "${aws_dynamodb_table.tfstate_lock.name}"
      encrypt        = true
    }
  }
  EOT
}