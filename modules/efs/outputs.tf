output "efs_id" {
  value = aws_efs_file_system.this.id
}

output "efs_arn" {
  value = aws_efs_file_system.this.arn
}

output "access_point_id" {
  value = aws_efs_access_point.wordpress.id
}

output "access_point_arn" {
  value = aws_efs_access_point.wordpress.arn
}

output "plugins_access_point_id" {
  description = "shared_code_dirs kapaliyken null"
  value       = one(aws_efs_access_point.plugins[*].id)
}

output "plugins_access_point_arn" {
  value = one(aws_efs_access_point.plugins[*].arn)
}

output "themes_access_point_id" {
  description = "shared_code_dirs kapaliyken null"
  value       = one(aws_efs_access_point.themes[*].id)
}

output "themes_access_point_arn" {
  value = one(aws_efs_access_point.themes[*].arn)
}
