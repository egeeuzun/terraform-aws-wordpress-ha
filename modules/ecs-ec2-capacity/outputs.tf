output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.this.name
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.this.name
}

output "instance_role_name" {
  value = aws_iam_role.instance.name
}
