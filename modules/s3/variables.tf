variable "name" {
  type = string
}

variable "cloudfront_distribution_arn" {
  description = "Bucket'i okuyabilecek CloudFront dagitiminin ARN'i. Bos birakilirsa bucket policy'ye okuma izni hic yazilmaz ve bucket disaridan tamamen erisilemez olur."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "destroy sirasinda bucket icindeki nesneleri de siler. Uretimde false yapilmali: medya kutuphanesi tek bir yanlis destroy ile gider."
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Medya bucket'inda versiyonlama. EFS'in AWS Backup karsiligi burada budur: yanlislikla silinen veya uzerine yazilan bir gorsel geri alinabilir. Eski versiyonlar noncurrent_version_expiration_days sonunda temizlendigi icin maliyet sinirli kalir."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Guncel olmayan nesne versiyonlarinin saklanma suresi. Versiyonlama acikken bu kural olmazsa her uzerine yazma bucket'ta kalici olarak birikir."
  type        = number
  default     = 30
}

variable "abort_incomplete_multipart_days" {
  description = "Yarim kalan multipart upload'larin temizlenme suresi. Bu parcalar ListObjects ile gorunmez ama depolama olarak faturalanir; kural olmazsa sessizce birikirler."
  type        = number
  default     = 7
}

variable "intelligent_tiering_enabled" {
  description = "Nesneleri INTELLIGENT_TIERING sinifina gecirir. WordPress medya kutuphanesi cogunlukla 128 KB altinda kucuk thumbnail'lerden olusur; bu nesneler zaten tiering'e girmez ama nesne basi izleme ucreti alinir. Yalnizca buyuk dosya agirlikli bir kutuphanede kazanc saglar, o yuzden varsayilan kapali."
  type        = bool
  default     = false
}

variable "intelligent_tiering_min_object_size" {
  description = "Tiering'e gonderilecek en kucuk nesne boyutu (byte). 128 KB alti nesneler S3 tarafinda zaten tiering'e alinmadigi icin varsayilan bu esikte."
  type        = number
  default     = 131072
}

variable "cors_allowed_origins" {
  description = "Bucket'a tarayicidan dogrudan erisecek origin'ler. Varliklar CloudFront uzerinden ayni domainden servis edildiginde CORS gerekmez; webfont'lar veya tarayiciden dogrudan yukleme yapan bir eklenti icin site adresi buraya yazilir. Bos birakilirsa CORS yapilandirmasi hic olusturulmaz."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Veri tutan kaynaklara eklenecek etiketler (data-residency, data-class)"
  type        = map(string)
  default     = {}
}
