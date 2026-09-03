output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "cache_sg_id" {
  value = aws_security_group.cache.id
}

output "efs_sg_id" {
  value = aws_security_group.efs.id
}
