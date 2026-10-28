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

  # Ornek tfvars'taki yer tutucu (ACCOUNT_ID/CONNECTION_ID) AWS'ye gidince
  # "codestar-connections:PassConnection" ve "MalformedPolicyDocument"
  # hatalari verir; burada anlasilir bir mesajla durur.
  validation {
    condition     = can(regex("^arn:aws[a-z-]*:(codestar-connections|codeconnections):[a-z0-9-]+:[0-9]{12}:connection/[0-9a-f-]+$", var.codestar_connection_arn))
    error_message = "enable_cicd acik ama codestar_connection_arn gecerli bir baglanti ARN'i degil (ornek degerde mi kaldi?). Pipeline istemiyorsaniz enable_cicd = false yapin."
  }
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
