output "cluster_name" { value = aws_ecs_cluster.main.name }
output "cluster_arn"  { value = aws_ecs_cluster.main.arn }
output "service_name" { value = aws_ecs_service.app.name }
output "task_family"  { value = aws_ecs_task_definition.app.family }