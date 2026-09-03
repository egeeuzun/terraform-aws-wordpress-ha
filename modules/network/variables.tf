variable "name" {
  description = "Kaynak isim öneki (project-env)"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_map" {
  description = "Public katman. AZ başına tam bir kayıt olmalı; NAT gateway eşleştirmesi AZ anahtarlı."
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))

  validation {
    condition     = length(var.public_subnet_map) >= 2
    error_message = "Multi-AZ için en az iki public subnet gerekir (ALB en az iki AZ ister)."
  }

  validation {
    condition     = length(distinct([for s in var.public_subnet_map : s.az])) == length(var.public_subnet_map)
    error_message = "Her AZ'de yalnızca bir public subnet olmalı; aynı AZ'de iki kayıt NAT gateway eşleştirmesini belirsizleştirir."
  }
}

variable "app_subnet_map" {
  description = "ECS/Fargate görevlerinin çalıştığı private katman."
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))

  validation {
    condition     = length(distinct([for s in var.app_subnet_map : s.az])) >= 2
    error_message = "App katmanı en az iki farklı AZ'ye yayılmalı."
  }
}

variable "data_subnet_map" {
  description = "RDS, ElastiCache ve EFS mount target'larının bulunduğu izole katman."
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))

  validation {
    condition     = length(distinct([for s in var.data_subnet_map : s.az])) >= 2
    error_message = "Data katmanı en az iki farklı AZ'ye yayılmalı (DB subnet group ve EFS mount target'ları bunu şart koşar)."
  }
}
