variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "budget_emails" {
  description = "Butce alarmlarinin gidecegi e-posta adresleri"
  type        = list(string)

  validation {
    condition     = length(var.budget_emails) > 0
    error_message = "En az bir e-posta adresi gerekli; aliciya gitmeyen bir butce alarmi ise yaramaz."
  }
}

variable "budget_thresholds_usd" {
  description = "Gerceklesen aylik harcama icin alarm esikleri (USD). En buyugu butce limiti olur."
  type        = list(number)
  default     = [30, 60, 100]

  validation {
    condition     = length(var.budget_thresholds_usd) > 0 && length(var.budget_thresholds_usd) <= 4
    error_message = "1 ile 4 arasinda esik verin; AWS Budgets butce basina en fazla 5 bildirim kabul ediyor (biri tahmin alarmi)."
  }
}

variable "state_noncurrent_expiration_days" {
  description = "State dosyasinin eski versiyonlarinin saklanma suresi"
  type        = number
  default     = 90
}
