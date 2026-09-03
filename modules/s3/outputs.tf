output "static_bucket_name" {
  value = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  value = aws_s3_bucket.static.arn
}

output "static_bucket_regional_domain_name" {
  description = "CloudFront S3 origin'inin domain'i. Bolgesel adres kullaniliyor; global adres yeni bucket'larda DNS yayilana kadar 307 yonlendirme dondurur ve CloudFront bunu viewer'a aktarir."
  value       = aws_s3_bucket.static.bucket_regional_domain_name
}
