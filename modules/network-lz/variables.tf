variable "name" {
  description = "Kaynak isim oneki (project-env)"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "local_zone" {
  description = "Local Zone adi, ornek: eu-central-1-ist-1a"
  type        = string
}

variable "nat_in_local_zone" {
  description = "NAT gateway'i Local Zone'a koyar. Kapaliyken parent AZ'de durur ve LZ'nin dis trafigi Frankfurt'tan cikar. Acmadan once Local Zone'un NAT gateway destekledigini dogrulayin."
  type        = bool
  default     = false
}
