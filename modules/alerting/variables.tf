variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "container_app_id" { type = string }
variable "container_app_name" { type = string }
variable "log_analytics_id" { type = string }
variable "alert_email" {
  description = "Destinataire des alertes (adresse du compte Azure for Students)."
  type        = string
}
variable "monthly_budget_eur" {
  description = "Plafond mensuel surveille par l'alerte de budget."
  type        = number
  default     = 15
}
variable "tags" {
  type    = map(string)
  default = {}
}
