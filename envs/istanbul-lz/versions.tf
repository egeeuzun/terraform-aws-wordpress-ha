terraform {
  # use_lockfile (S3 native state locking) 1.11 ile GA oldu.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79.0, < 6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # bucket ve region backend.hcl'den gelir (bkz. backend.hcl.example):
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "istanbul-lz/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
