output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "service_name" {
  value = aws_ecs_service.wordpress.name
}

output "task_definition_family" {
  value = aws_ecs_task_definition.wordpress.family
}
