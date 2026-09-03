variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "ecr_repository_url" {
  description = "CodeBuild'in imaji pushladigi repo adresi (ecr modulunun ciktisi)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "CodeBuild push izninin kapsami"
  type        = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "codestar_connection_arn" {
  description = "GitHub/Bitbucket CodeStar Connections ARN (konsoldan bir kez elle onaylanmali)"
  type        = string
}

variable "repository_id" {
  description = "Ornek: kullanici/wordpress-repo"
  type        = string
}

variable "branch" {
  type    = string
  default = "main"
}

variable "artifact_retention_days" {
  description = "Pipeline artifactlarinin bucket'ta kalma suresi. Artifact store versiyonlu olmak zorunda oldugu icin bu kural olmadan her calisma kalici olarak birikir."
  type        = number
  default     = 30
}
