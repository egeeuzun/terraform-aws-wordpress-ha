variable "name" {
  type = string
}

variable "resource_arns" {
  description = "Yedeklenecek kaynak ARN'leri (EFS, RDS)"
  type        = list(string)
}

variable "schedule" {
  description = "Cron formatinda yedekleme zamani (UTC)"
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  description = "Veri tutan kaynaklara eklenecek etiketler (data-residency, data-class)"
  type        = map(string)
  default     = {}
}
