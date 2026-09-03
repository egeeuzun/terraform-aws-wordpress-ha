output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "Bucket policy'nin AWS:SourceArn kosulunda kullandigi ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "waf_web_acl_arn" {
  value = try(aws_wafv2_web_acl.this[0].arn, null)
}
