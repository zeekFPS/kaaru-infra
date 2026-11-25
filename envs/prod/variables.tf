variable "environment" {
  description = "Nom de l'environnement (dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Tag owner impose par le cahier des charges."
  type        = string
}

variable "location" {
  description = "Region Azure. France Central pour rester dans l'UE."
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Resource group cible (cree par ce module)."
  type        = string
}

variable "unique_suffix" {
  description = "Suffixe unique pour le nom du Key Vault (unique au monde)."
  type        = string
}

variable "admin_ip_rules" {
  description = "IP publiques autorisees a joindre le Key Vault en secours."
  type        = list(string)
  default     = []
}

variable "alert_email" {
  description = "Adresse qui recoit les alertes Azure Monitor."
  type        = string
}

variable "monthly_budget_eur" {
  description = "Plafond de depense surveille par l'alerte de budget."
  type        = number
  default     = 15
}

variable "log_retention_days" {
  description = "Retention des logs dans Log Analytics (30 jours = offre gratuite)."
  type        = number
  default     = 30
}

variable "container_image" {
  description = "Image de l'API et du worker (meme image, commande differente)."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "api_min_replicas" {
  description = "0 = scale-to-zero, donc cout nul sans trafic."
  type        = number
  default     = 0
}

variable "api_max_replicas" {
  type    = number
  default = 3
}
