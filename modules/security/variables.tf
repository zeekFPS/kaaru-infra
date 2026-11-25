variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "storage_account_id" { type = string }
variable "links_table_id" { type = string }
variable "stats_table_id" { type = string }
variable "queue_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "apps_subnet_id" {
  description = "Sous-reseau autorise a joindre le coffre."
  type        = string
}
variable "log_analytics_id" {
  description = "Espace Log Analytics qui recoit les traces d'audit du coffre."
  type        = string
}
variable "suffix" {
  description = "Suffixe unique pour le nom du coffre (unique au monde)."
  type        = string
}
variable "admin_ip_rules" {
  description = "IP publiques autorisees en secours (poste de l'administrateur)."
  type        = list(string)
  default     = []
}
