variable "name" {
  type = string
}

variable "local_zone" {
  type = string
}

variable "subnet_id" {
  description = "Local Zone data subnet'i"
  type        = string
}

variable "private_ip" {
  description = "Sabit ozel IP. Instance degisse de WordPress'in DB_HOST'u ayni kalir."
  type        = string
}

variable "security_group_id" {
  description = "3306'ya yalnizca ECS task'larindan izin veren security group"
  type        = string
}

variable "instance_type" {
  description = "Istanbul Local Zone'da C7i, M7i ve R7i aileleri var"
  type        = string
  default     = "m7i.large"
}

variable "ubuntu_codename" {
  description = "26.04 (resolute) MariaDB 11.8 ile geliyor; Frankfurt'taki RDS ile ayni seri, dump'lar collation hatasi vermeden tasinir."
  type        = string
  default     = "resolute"
}

variable "ami_id" {
  description = "AMI'yi sabitler. Bos = ubuntu_codename ile eslesen en guncel Canonical imaji."
  type        = string
  default     = ""
}

variable "data_volume_size" {
  description = "Veri diskinin boyutu (GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password_ssm_name" {
  description = "Instance'in ilk acilista okudugu parola parametresinin adi"
  type        = string
}

variable "db_password_ssm_arn" {
  type = string
}

variable "snapshot_time_utc" {
  description = "Gunluk snapshot saati (UTC, HH:MM). 00:00 UTC = 03:00 Turkiye."
  type        = string
  default     = "00:00"
}

variable "snapshot_retention_count" {
  description = "Saklanacak gunluk snapshot sayisi"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Instance ve disklere eklenecek etiketler (data-residency, data-class)"
  type        = map(string)
  default     = {}
}
