# Deux identites, deux jeux de droits. L'API ne peut pas ecrire les
# statistiques, le worker ne peut pas modifier un lien : la separation est
# appliquee par RBAC, pas par convention de code.

resource "azurerm_user_assigned_identity" "api" {
  name                = "id-${var.prefix}-api"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "worker" {
  name                = "id-${var.prefix}-worker"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# --- API : lit les liens, ecrit les liens, depose des evenements ------------
resource "azurerm_role_assignment" "api_tables_links" {
  scope                = var.links_table_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_role_assignment" "api_blobs" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_role_assignment" "api_queue_send" {
  scope                = var.queue_id
  role_definition_name = "Storage Queue Data Message Sender"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# --- Worker : consomme la file et ecrit uniquement les compteurs -----------
resource "azurerm_role_assignment" "worker_queue_process" {
  scope                = var.queue_id
  role_definition_name = "Storage Queue Data Message Processor"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

resource "azurerm_role_assignment" "worker_tables_stats" {
  scope                = var.stats_table_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

# Lecture des compteurs cote API (pour /stats), sans droit d'ecriture.
resource "azurerm_role_assignment" "api_tables_stats_read" {
  scope                = var.stats_table_id
  role_definition_name = "Storage Table Data Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}
