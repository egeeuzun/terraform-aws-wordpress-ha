output "repository_url" {
  description = "Tag'siz repo adresi, ornek: 1234.dkr.ecr.eu-central-1.amazonaws.com/ad-wordpress"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "CodeBuild'in push izni icin"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  value = aws_ecr_repository.this.name
}
