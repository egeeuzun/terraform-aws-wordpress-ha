variable "name" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_https_enabled" {
  description = "ALB'de ACM sertifikasi tanimli mi. True ise CloudFront origin'e HTTPS ile gider (ALB 80'i HTTPS'e yonlendirdigi icin)."
  type        = bool
  default     = false
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "domain_name" {
  description = "Ornek: blog.example.com (bos ise CloudFront varsayilan domaini kullanilir)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID (bos ise kayit olusturulmaz)"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "us-east-1'deki ACM sertifikasi (CloudFront icin zorunlu bolge)"
  type        = string
  default     = ""
}

variable "admin_allowed_cidrs" {
  description = "Yönetim paneline (wp-admin, wp-login.php) erişebilecek kaynak IP'ler. Normalde Pritunl VPN'in Elastic IP'si. Boş bırakılırsa kısıtlama kuralı hiç oluşturulmaz ve panel herkese açık kalır."
  type        = list(string)
  default     = []
}

variable "admin_path_regex" {
  description = "Yönetim yüzeyi sayılan yollar. Küçük harfe çevrilmiş URI path ile eşleştirilir."
  type        = string
  default     = "^/(wp-admin|wp-login\\.php)"
}

variable "admin_public_path_regex" {
  description = "Yönetim yüzeyi içinde herkese açık kalması gereken yollar. admin-ajax.php WooCommerce'in frontend istekleri için zorunlu."
  type        = string
  default     = "^/wp-admin/admin-ajax\\.php"
}

variable "admin_upload_path_regex" {
  description = "Yönetilen WAF kural gruplarından muaf tutulacak medya yükleme ucu. İkili dosya gövdesi XSS/RFI imzalarına benzediği için yönetilen kurallar burada yanlış pozitif üretir. Muafiyet yalnızca admin IP kısıtı aktifken uygulanır."
  type        = string
  default     = "^/wp-admin/async-upload\\.php|^/wp-json/wp/v2/media"
}

variable "admin_write_path_regex" {
  description = "Yalnızca yazma metodlarında yönetim kısıtına giren yollar. Blok editörü görselleri REST medya ucuna POST eder; GET herkese açık kalır ki blok temaların frontend okumaları bozulmasın."
  type        = string
  default     = "^/wp-json/wp/v2/media"
}

variable "admin_write_methods_regex" {
  description = "admin_write_path_regex ile eşleşen yollarda kısıtlanacak HTTP metodları. Küçük harfe çevrilmiş metod ile eşleştirilir."
  type        = string
  default     = "^(post|put|patch|delete)$"
}

variable "static_bucket_regional_domain_name" {
  description = "S3 origin'inin bolgesel domain adi (s3 modulunden gelir)."
  type        = string
}

variable "static_path_patterns" {
  description = "S3 origin'ine yonlenecek yol desenleri. Varsayilan /static/*: imajla birlikte gelen veya deploy sirasinda bucket'a yuklenen varliklar icin ayrilmis onek."
  type        = list(string)
  default     = ["/static/*"]
}

variable "offload_uploads_to_s3" {
  description = "/wp-content/uploads/* isteklerini ALB yerine S3 origin'ine yonlendirir. Yalnizca konteyner imajinda medyayi S3'e yazan bir eklenti (ornegin S3-Uploads) kuruluyken acilmali; aksi halde nesneler bucket'ta bulunmadigi icin butun gorseller 403 doner."
  type        = bool
  default     = false
}
