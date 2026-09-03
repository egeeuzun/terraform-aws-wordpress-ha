variable "name" {
  description = "Kaynak isim öneki (project-env)"
  type        = string
}

variable "vpc_id" {
  description = "Security group'ların oluşturulacağı VPC"
  type        = string
}

variable "container_port" {
  description = "WordPress konteynerinin dinlediği port; ALB target group ve ECS task ile aynı olmak zorunda"
  type        = number
  default     = 80
}

variable "alb_ingress_cidrs" {
  description = "ALB'ye 80/443 erişimi olan CIDR blokları. Önünde CloudFront varsa CloudFront origin-facing prefix list'e daraltılabilir."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpn_sg_ids" {
  description = "Pritunl VPN security group'ları. Verilirse app ve data katmanına yönetimsel erişim açılır; boşsa özel katmanlara sadece ALB/ECS üzerinden ulaşılır."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tüm security group'lara eklenecek ek tag'ler"
  type        = map(string)
  default     = {}
}

variable "alb_ingress_prefix_list_ids" {
  description = "ALB'ye erişebilecek prefix list'ler. CloudFront'un origin-facing prefix list'i verilirse ALB'ye yalnızca CloudFront edge'leri ulaşır ve ALB adresi üzerinden WAF baypası kapanır."
  type        = list(string)
  default     = []
}

variable "alb_origin_ports" {
  description = "Prefix list kuralının açacağı portlar. CloudFront origin'e tek protokolle bağlandığı için tek port yeterli; prefix list girdileri security group kural kotasına (60) sayıldığından iki port kotayı aşar."
  type        = list(number)
  default     = [80]
}
