# Faz 1 baseline: Frankfurt, ECS Fargate, RDS. Istanbul Local Zone'a gecisten
# once olculen "once" hali. Task'lar durumsuz (EFS yok, medya S3'te) ki Local
# Zone ortamiyla ayni uygulama mimarisi karsilastirilsin.

locals {
  # Residency Guard ve maliyet raporlari bu etiketlerle filtreler.
  default_tags = {
    project     = "lz-woo"
    phase       = var.phase
    environment = var.env
    managed-by  = "terraform"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.default_tags
  }
}

# CloudFront'a bagli WAF ve ACM sertifikasi us-east-1'de olmak zorunda.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.default_tags
  }
}

module "main" {
  source = "../../main"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project = var.project
  env     = var.env
  region  = var.region

  az_count = 2

  db_instance_class   = "db.t3.micro"
  create_read_replica = var.create_read_replica
  desired_count       = 2
  enable_waf          = true

  # Seed kiti ECS Exec ile calistirilir (wp eval-file /usr/src/shop-seed/seed.php)
  enable_ecs_exec = true

  enable_efs             = false
  offload_uploads_to_s3  = true
  enable_plugin_installs = false

  enable_vpn                = var.enable_vpn
  vpn_admin_cidrs           = var.vpn_admin_cidrs
  vpn_wireguard_port        = var.vpn_wireguard_port
  admin_extra_allowed_cidrs = var.admin_extra_allowed_cidrs

  container_image = var.container_image
  image_tag       = var.image_tag

  enable_cicd             = var.enable_cicd
  codestar_connection_arn = var.codestar_connection_arn
  repository_id           = var.repository_id
  branch                  = var.branch
}
