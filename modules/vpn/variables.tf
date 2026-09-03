variable "name" {
  description = "Kaynak isim öneki (project-env)"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Pritunl'un çalışacağı public subnet. Diyagramda public-subnet-1a."
  type        = string
}

variable "admin_cidrs" {
  description = "Pritunl yönetim konsoluna (443) erişebilecek CIDR'ler. 0.0.0.0/0 kabul edilmez."
  type        = list(string)
}

variable "wireguard_port" {
  description = "Pritunl sunucusunun WireGuard portu (konsolda sunucu ayarlarında görünür). null verilirse WireGuard portu hiç açılmaz."
  type        = number
  default     = null
}

variable "client_cidrs" {
  description = "VPN istemcilerinin bağlanabileceği CIDR'ler. İstemciler gezici olduğu için varsayılan açık."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "acme_cidrs" {
  description = "Let's Encrypt HTTP-01 doğrulaması için 80 portunu açan CIDR'ler. Sertifika alınmayacaksa boş liste verin."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ubuntu_codename" {
  description = "Pritunl'un çalışacağı Ubuntu sürümünün kod adı. Hem AMI aramasını hem de MongoDB/Pritunl apt suite'lerini besler; ikisi ayrışamaz. 24.04 LTS = noble, 26.04 LTS = resolute (MongoDB sunucu paketleri henüz yok, bkz. main.tf)."
  type        = string
  default     = "noble"
}

variable "ami_id" {
  description = "Belirli bir AMI'ye sabitlemek için. Boş bırakılırsa ubuntu_codename ile eşleşen en güncel Canonical imajı bulunur. AMI id'leri bölgeye özeldir; verilen id ubuntu_codename ile aynı sürüm olmalı."
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id ya boş olmalı ya da geçerli bir AMI id (ami-...) olmalı."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "root_volume_size" {
  description = "MongoDB de bu diskte durur; Pritunl konfigürasyonu buradadır."
  type        = number
  default     = 20
}
