output "site_url" {
  value = "https://${module.main.cloudfront_domain_name}"
}

output "availability_zones" {
  value = module.main.availability_zones
}

output "vpc_id" {
  value = module.main.vpc_id
}

output "nat_public_ips" {
  value = module.main.nat_public_ips
}

output "vpn_admin_url" {
  value = module.main.vpn_admin_url
}

output "vpn_setup_key_command" {
  value = module.main.vpn_setup_key_command
}

output "vpn_default_password_command" {
  value = module.main.vpn_default_password_command
}

output "alb_dns_name" {
  value = module.main.alb_dns_name
}

output "rds_endpoint" {
  value = module.main.rds_endpoint
}

output "db_password_ssm_parameter" {
  value = module.main.db_password_ssm_parameter
}

output "ecr_repository_url" {
  value = module.main.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.main.ecs_cluster_name
}

output "static_bucket_name" {
  value = module.main.static_bucket_name
}

output "admin_password_ssm_name" {
  value = module.main.admin_password_ssm_name
}
