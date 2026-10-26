variable "name" {
  type = string
}

variable "data_subnet_ids" {
  type = list(string)
}

variable "efs_sg_id" {
  type = string
}

variable "shared_code_dirs" {
  description = "plugins ve themes icin ayri access point'ler olusturur. wp-admin uzerinden eklenti/tema kurulumu acilacaksa gerekli: kurulan dosyalarin butun task'larda ayni ve kalici olmasini saglar."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Veri tutan kaynaklara eklenecek etiketler (data-residency, data-class)"
  type        = map(string)
  default     = {}
}
