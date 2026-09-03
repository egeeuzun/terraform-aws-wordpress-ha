terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewerAndCloudFrontHeaders-2022-06"
}

data "aws_cloudfront_origin_request_policy" "cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_response_headers_policy" "cors" {
  name = "Managed-SimpleCORS"
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.name} WordPress dagitimi"
  price_class     = "PriceClass_100"
  web_acl_id      = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : null
  aliases         = var.domain_name != "" && var.acm_certificate_arn != "" ? [var.domain_name] : []

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port  = 80
      https_port = 443

      origin_protocol_policy = var.alb_https_enabled ? "https-only" : "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = var.static_bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id
  }

  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = true
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.s3_path_patterns

    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "s3-static"
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD", "OPTIONS"]
      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
      response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors.id
      compress                   = true
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/wp-content/*"
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == ""
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = { Name = "${var.name}-cdn" }
}

resource "aws_route53_record" "this" {
  count   = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_origin_access_control" "static" {
  name                              = "${var.name}-static-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_path_patterns = concat(
    var.offload_uploads_to_s3 ? ["/wp-content/uploads/*"] : [],
    var.static_path_patterns,
  )

  admin_ip_restriction = var.enable_waf && length(var.admin_allowed_cidrs) > 0
}

resource "aws_wafv2_ip_set" "admin" {
  count    = local.admin_ip_restriction ? 1 : 0
  provider = aws.us_east_1

  name               = "${var.name}-admin-allowed"
  description        = "Yonetim paneline erisebilen kaynak IP adresleri - Pritunl EIP"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.admin_allowed_cidrs

  tags = { Name = "${var.name}-admin-allowed" }
}

resource "aws_wafv2_web_acl" "this" {
  count    = var.enable_waf ? 1 : 0
  provider = aws.us_east_1

  name  = "${var.name}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.admin_ip_restriction ? [1] : []

    content {
      name     = "AdminIpRestriction"
      priority = 0

      action {
        block {}
      }

      statement {
        and_statement {
          statement {
            regex_match_statement {
              regex_string = var.admin_path_regex

              field_to_match {
                uri_path {}
              }

              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }

          statement {
            not_statement {
              statement {
                regex_match_statement {
                  regex_string = var.admin_public_path_regex

                  field_to_match {
                    uri_path {}
                  }

                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }
          }

          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.admin[0].arn
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-admin-ip-restriction"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.admin_ip_restriction ? [1] : []

    content {
      name     = "AdminRestWriteRestriction"
      priority = 1

      action {
        block {}
      }

      statement {
        and_statement {
          statement {
            regex_match_statement {
              regex_string = var.admin_write_path_regex

              field_to_match {
                uri_path {}
              }

              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }

          statement {
            regex_match_statement {
              regex_string = var.admin_write_methods_regex

              field_to_match {
                method {}
              }

              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }

          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.admin[0].arn
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-admin-rest-write"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.admin_ip_restriction ? [1] : []

    content {
      name     = "AllowAdminMediaUpload"
      priority = 2

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {
            regex_match_statement {
              regex_string = var.admin_upload_path_regex

              field_to_match {
                uri_path {}
              }

              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }

          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.admin[0].arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-admin-media-upload"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"

          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }
}
