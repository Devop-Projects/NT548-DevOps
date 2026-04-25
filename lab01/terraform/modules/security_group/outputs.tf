output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "app_sg_id"     { value = aws_security_group.app.id }