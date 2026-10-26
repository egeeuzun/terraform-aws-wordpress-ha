variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "container_port" {
  description = "Target group'un hedeflediği konteyner portu; ECS task ve security group ile aynı olmak zorunda"
  type        = number
  default     = 80
}

variable "certificate_arn" {
  description = "ACM sertifika ARN (bos ise sadece HTTP listener olusur)"
  type        = string
  default     = ""
}

variable "health_check_path" {
  type    = string
  default = "/health.php"
}
