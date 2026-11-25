resource "azurerm_container_registry" "this" {
  name                = "acr${var.prefix}${substr(md5(var.resource_group_name), 0, 6)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

# Les deux identites tirent l'image sans mot de passe de registre.
resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.api_identity_principal_id
}

resource "azurerm_role_assignment" "worker_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.worker_identity_principal_id
}

resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${var.prefix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_id

  # Injection VNet : la sortie des conteneurs passe par snet-apps, donc par le
  # NSG et par le service endpoint de stockage. Sans cela, le compte de
  # stockage devrait accepter le monde entier.
  infrastructure_subnet_id = var.infrastructure_subnet_id

  tags = var.tags
}

locals {
  common_env = [
    { name = "SERVICE_NAME", value = "kaaru" },
    { name = "ENVIRONMENT", value = "prod" },
    { name = "STORE_BACKEND", value = "azure" },
    { name = "STORAGE_ACCOUNT_URL", value = var.storage_account_url },
    { name = "AZURE_CLIENT_ID", value = var.api_identity_client_id },
    { name = "LOG_LEVEL", value = "INFO" },
  ]
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${var.prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.api_identity_id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = var.api_identity_id
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.api_min_replicas
    max_replicas = var.api_max_replicas

    container {
      name   = "api"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }
  }

  lifecycle {
    # L'image est poussee par la CI apres le apply : on ne veut pas que
    # Terraform la ramene a la valeur du tfvars a chaque plan.
    ignore_changes = [template[0].container[0].image]
  }
}

# Job d'agregation. Declenchement planifie toutes les deux minutes : aucun
# secret, aucun couplage a KEDA, et un cout nul entre deux passages.
# La variante evenementielle (KEDA azure-queue) est decrite dans docs/architecture.md.
resource "azurerm_container_app_job" "worker" {
  name                         = "job-${var.prefix}-stats"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  location                     = var.location
  tags                         = var.tags

  replica_timeout_in_seconds = 300
  replica_retry_limit        = 2

  identity {
    type         = "UserAssigned"
    identity_ids = [var.worker_identity_id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = var.worker_identity_id
  }

  schedule_trigger_config {
    cron_expression          = var.worker_schedule
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "worker"
      image   = var.container_image
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["python", "-m", "app.worker"]

      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.worker_identity_client_id
      }

      env {
        name  = "WORKER_RUN_ONCE"
        value = "1"
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
