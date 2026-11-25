terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    # Les tables et les files sont creees par le plan de controle ARM.
    # Pourquoi pas les ressources azurerm : celles-ci passent par le plan de
    # donnees et exigent la cle du compte, or la cle partagee est desactivee
    # et le pare-feu reseau ferme par defaut. ARM reste toujours joignable.
    azapi = {
      source = "azure/azapi"
    }
  }
}

resource "azurerm_storage_account" "this" {
  name                     = lower("st${var.prefix}${var.name_suffix}")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version = "TLS1_2"

  # Aucune cle partagee : l'application n'utilise que l'identite managee.
  # Desactiver la cle est ce qui rend l'identite reellement obligatoire.
  shared_access_key_enabled = false

  # Un conteneur public rendrait les logos et les exports enumerables.
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  # Pare-feu : refus par defaut. Seul le sous-reseau applicatif est autorise,
  # via son service endpoint. Les appels de plan de controle (Terraform, ARM)
  # ne sont pas concernes par ces regles.
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.apps_subnet_id]
  }

  tags = var.tags
}

# --- Blobs : logos uploades et exports PNG/SVG ------------------------------
resource "azurerm_storage_container" "logos" {
  name                  = "logos"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "exports" {
  name                  = "exports"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "purge-exports"
    enabled = true
    filters {
      prefix_match = ["exports/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}

# --- Tables : source de verite des liens et des compteurs --------------------
resource "azapi_resource" "table_links" {
  type                      = "Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01"
  name                      = "links"
  parent_id                 = "${azurerm_storage_account.this.id}/tableServices/default"
  schema_validation_enabled = false
  body                      = { properties = {} }
}

resource "azapi_resource" "table_stats" {
  type                      = "Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01"
  name                      = "scanstats"
  parent_id                 = "${azurerm_storage_account.this.id}/tableServices/default"
  schema_validation_enabled = false
  body                      = { properties = {} }
}

# --- File : tampon entre la redirection et l'agregation ---------------------
resource "azapi_resource" "queue_scans" {
  type                      = "Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01"
  name                      = "scan-events"
  parent_id                 = "${azurerm_storage_account.this.id}/queueServices/default"
  schema_validation_enabled = false
  body                      = { properties = {} }
}
