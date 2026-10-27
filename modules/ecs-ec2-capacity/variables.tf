variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Instance'larin acilacagi subnet'ler (Local Zone app subnet'i)"
  type        = list(string)
}

variable "cluster_name" {
  description = "Instance'larin katilacagi ECS cluster. Cluster'dan once bilindigi icin ad olarak verilir (dongu olusmasin)."
  type        = string
}

variable "instance_type" {
  description = "Istanbul Local Zone'da C7i, M7i ve R7i aileleri var"
  type        = string
  default     = "m7i.large"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  description = "Rolling deploy ayni anda eski ve yeni task'lari calistirdigi icin desired_count'un iki katini tasiyabilmeli"
  type        = number
  default     = 4
}

variable "root_volume_size" {
  description = "ECS AMI'si 30 GB'tan kucuk disk kabul etmiyor"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Instance ve disklerine eklenecek etiketler"
  type        = map(string)
  default     = {}
}
