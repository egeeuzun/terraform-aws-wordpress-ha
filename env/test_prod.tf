terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79.0, < 6.0.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "default"

  default_tags {
    tags = {
      Environment = "Tyesest"
      Region      = "eu-central-1"
      Terraform   = "true"
    }
  }
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "default"

  default_tags {
    tags = {
      Environment = "Test"
      Terraform   = "true"
    }
  }
}

module "main" {
  source = "../main"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project = "wordpress HA"
  env     = "Test"
  region  = "eu-central-1"

  az_count = 2

  db_instance_class   = "db.t3.micro"
  create_read_replica = true
  desired_count       = 2
  enable_waf          = true

  enable_ecs_exec = true

  offload_uploads_to_s3 = true

  enable_vpn      = true
  vpn_admin_cidrs = [""]

  vpn_wireguard_port = 12712

  enable_cicd             = true
  codestar_connection_arn = "arn:aws:codestar-connections:eu-central-1:ACCOUNT_ID:connection/CONNECTION_ID"
  repository_id           = "ORG/REPO"
  branch                  = "main"
}

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
