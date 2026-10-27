# Hesap basina bir kez kurulur: envs/* ortamlarinin state bucket'i ve maliyet
# alarmi. Kendi state'i yereldedir (terraform.tfstate, git'e girmez); kaybolursa
# kaynaklar import ile geri alinabilir.

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79.0, < 6.0.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "lz-woo"
      component  = "bootstrap"
      managed-by = "terraform"
    }
  }
}

# --- Terraform state ---------------------------------------------------------
# Kilitleme S3'un kendi lock dosyasiyla (use_lockfile) yapilir, DynamoDB yok.
# State'te DB parolasi ve WordPress salt'lari duz metin durur: bucket sifreli,
# disaridan kapali ve versiyonlu (bozulan bir state geri alinabilsin).

resource "aws_s3_bucket" "state" {
  bucket_prefix = "lz-woo-tfstate-"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.state_noncurrent_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "state" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# --- Maliyet alarmi ----------------------------------------------------------
# Hesabin tamami icin aylik butce. Her esik gerceklesen harcamayi, son esik
# ayrica ay sonu tahminini izler. Local Zone instance'lari, NAT gateway'ler ve
# unutulan snapshot'lar sessizce birikebildigi icin her olcum turundan sonra
# destroy edilmesi gerekir; bu alarm unutulani yakalamak icin.

resource "aws_budgets_budget" "monthly" {
  name         = "lz-woo-monthly"
  budget_type  = "COST"
  limit_amount = tostring(max(var.budget_thresholds_usd...))
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.budget_thresholds_usd

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "ABSOLUTE_VALUE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.budget_emails
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_emails
  }
}
