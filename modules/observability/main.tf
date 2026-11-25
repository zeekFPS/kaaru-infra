resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.tags
}

# Application Insights branche sur le meme espace de travail : une seule
# facture d'ingestion, et les traces du job se lisent au meme endroit.
resource "azurerm_application_insights" "this" {
  name                = "appi-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = var.tags
}
