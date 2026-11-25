variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "address_space" {
  description = "Plan d'adressage du VNet. /16 laisse de la place sans collision avec un reseau local."
  type        = list(string)
  default     = ["10.42.0.0/16"]
}
variable "apps_subnet_prefix" {
  description = "Sous-reseau des Container Apps (delegue, /23 minimum)."
  type        = string
  default     = "10.42.0.0/23"
}
variable "data_subnet_prefix" {
  description = "Sous-reseau des donnees (points de terminaison prives)."
  type        = string
  default     = "10.42.8.0/24"
}
variable "tags" {
  type    = map(string)
  default = {}
}
