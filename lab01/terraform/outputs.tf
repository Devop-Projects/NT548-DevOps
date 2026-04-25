output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "URL truy cap ung dung qua ALB"
  value       = "http://${module.alb.alb_dns_name}"
}

output "bastion_public_ip" {
  description = "SSH vao Bastion"
  value       = module.ec2.bastion_public_ip
}

output "rds_endpoint" {
  description = "MySQL connection string"
  value       = module.rds.db_endpoint
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "nat_gateway_ip" {
  value = module.vpc.nat_gateway_ip
}