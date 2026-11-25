variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "log_analytics_id" { type = string }
variable "infrastructure_subnet_id" {
  description = "Sous-reseau delegue qui porte l'environnement Container Apps."
  type        = string
}
variable "storage_account_name" { type = string }
variable "storage_account_url" { type = string }
variable "api_identity_id" { type = string }
variable "api_identity_client_id" { type = string }
variable "api_identity_principal_id" { type = string }
variable "worker_identity_id" { type = string }
variable "worker_identity_client_id" { type = string }
variable "worker_identity_principal_id" { type = string }
variable "container_image" { type = string }
variable "api_min_replicas" {
  type    = number
  default = 0
}
variable "api_max_replicas" {
  type    = number
  default = 3
}
variable "worker_schedule" {
  description = "NCRONTAB de passage du worker (toutes les 2 minutes)."
  type        = string
  default     = "*/2 * * * *"
}
