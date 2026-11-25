terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }

  # Etat distant : renseigner backend.hcl avant le premier init.
  # Sans backend, l'etat reste local et le projet n'est pas reproductible.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  prefix = "kaaru"

  # Les trois tags imposes par le cahier des charges, plus deux utiles au
  # quotidien. owner est le seul a porter une personne.
  tags = {
    owner       = var.owner
    project     = "kaaru"
    environment = var.environment
    course      = "cloud-computing"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# --- Reseau -----------------------------------------------------------------
module "network" {
  source              = "../../modules/network"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# --- Supervision ------------------------------------------------------------
module "observability" {
  source              = "../../modules/observability"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  retention_days      = var.log_retention_days
  tags                = local.tags
}

# --- Stockage ---------------------------------------------------------------
module "storage" {
  source              = "../../modules/storage"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  apps_subnet_id      = module.network.apps_subnet_id
  tags                = local.tags
}

# --- Identites, RBAC, coffre -----------------------------------------------
module "security" {
  source              = "../../modules/security"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  storage_account_id  = module.storage.account_id
  links_table_id      = module.storage.links_table_id
  stats_table_id      = module.storage.stats_table_id
  queue_id            = module.storage.queue_id
  apps_subnet_id      = module.network.apps_subnet_id
  log_analytics_id    = module.observability.workspace_id
  suffix              = var.unique_suffix
  admin_ip_rules      = var.admin_ip_rules
  tags                = local.tags
}

# --- Calcul ----------------------------------------------------------------
module "compute" {
  source                       = "../../modules/compute"
  prefix                       = local.prefix
  location                     = var.location
  resource_group_name          = azurerm_resource_group.this.name
  tags                         = local.tags
  log_analytics_id             = module.observability.workspace_id
  infrastructure_subnet_id     = module.network.apps_subnet_id
  storage_account_name         = module.storage.account_name
  storage_account_url          = module.storage.blob_endpoint
  api_identity_id              = module.security.api_identity_id
  api_identity_client_id       = module.security.api_identity_client_id
  api_identity_principal_id    = module.security.api_identity_principal_id
  worker_identity_id           = module.security.worker_identity_id
  worker_identity_client_id    = module.security.worker_identity_client_id
  worker_identity_principal_id = module.security.worker_identity_principal_id
  container_image              = var.container_image
  api_min_replicas             = var.api_min_replicas
  api_max_replicas             = var.api_max_replicas
}

# --- Alertes et tableau de bord --------------------------------------------
module "alerting" {
  source              = "../../modules/alerting"
  prefix              = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  resource_group_id   = azurerm_resource_group.this.id
  container_app_id    = module.compute.api_id
  container_app_name  = "ca-${local.prefix}-api"
  log_analytics_id    = module.observability.workspace_id
  alert_email         = var.alert_email
  monthly_budget_eur  = var.monthly_budget_eur
  tags                = local.tags
}

# --- Gouvernance : dernier, pour ne jamais bloquer la construction ---------
module "governance" {
  source            = "../../modules/governance"
  resource_group_id = azurerm_resource_group.this.id
  tags              = local.tags
  depends_on        = [module.compute, module.alerting]
}
