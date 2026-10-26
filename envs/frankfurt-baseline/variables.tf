variable "project" {
  description = "Kaynak adlarinin oneki (project-env). Eski env/ dizininden tasinan bir kurulumda adlar degismesin diye eski degerler verilmeli (\"wordpress HA\" / \"Test\"); aksi halde her sey yeniden olusturulur."
  type        = string
  default     = "lz-woo"
}

variable "env" {
  type    = string
  default = "baseline"
}

variable "phase" {
  description = "phase etiketi: baseline | hybrid | lz"
  type        = string
  default     = "baseline"

  validation {
    condition     = contains(["baseline", "hybrid", "lz"], var.phase)
    error_message = "phase baseline, hybrid veya lz olmali."
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "create_read_replica" {
  description = "Imaj yalnizca writer endpoint'i kullanir; replica okuma yuku almaz, sadece diyagramdaki HA topolojisi icin."
  type        = bool
  default     = true
}

variable "enable_vpn" {
  type    = bool
  default = false
}

variable "vpn_admin_cidrs" {
  type    = list(string)
  default = []
}

variable "vpn_wireguard_port" {
  type    = number
  default = null
}

variable "admin_extra_allowed_cidrs" {
  description = "wp-admin'e WAF uzerinden erisebilecek ek CIDR'ler (ornegin ev IP'niz /32)"
  type        = list(string)
  default     = []
}

variable "enable_cicd" {
  type    = bool
  default = false
}

variable "codestar_connection_arn" {
  type    = string
  default = ""
}

variable "repository_id" {
  description = "Imajin build edilecegi repo, ornek: kullanici/wordpress-shop-demo"
  type        = string
  default     = ""
}

variable "branch" {
  type    = string
  default = "main"
}
