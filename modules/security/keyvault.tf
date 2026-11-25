# Coffre-fort du projet.
#
# Il est cree et cable, mais volontairement vide : la conception n'a aucun
# secret d'application a stocker (pas de cle de stockage, pas de mot de passe de
# registre, pas de chaine de connexion). Le coffre sert de garde-fou pour tout
# secret futur, et son acces est deja restreint par RBAC.

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC uniquement : pas d'access policy, donc tout passe par des roles
  # auditables et nominatifs.
  rbac_authorization_enabled = true

  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  # Seul le sous-reseau applicatif peut joindre le coffre.
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.apps_subnet_id]
    ip_rules                   = var.admin_ip_rules
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "api_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_role_assignment" "worker_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

# Les traces de lecture du coffre sont ce qui permet de repondre a la question
# "qui a lu ce secret, et quand".
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-keyvault"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
