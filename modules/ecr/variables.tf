variable "name" {
  type = string
}

variable "image_retention_count" {
  description = "Lifecycle policy'nin tuttugu son imaj sayisi"
  type        = number
  default     = 10
}
