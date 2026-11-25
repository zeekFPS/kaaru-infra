# Quatre signaux, quatre questions differentes :
#   1. est-ce que l'application repond ?        (redemarrages)
#   2. est-ce qu'elle repond correctement ?     (erreurs 5xx)
#   3. est-ce qu'elle repond assez vite ?       (latence)
#   4. est-ce que le budget derive ?            (depense)

resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-${var.prefix}"
  resource_group_name = var.resource_group_name
  short_name          = "kaaruops"
  tags                = var.tags

  email_receiver {
    name                    = "proprietaire"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# --- 1. Erreurs serveur -----------------------------------------------------
resource "azurerm_monitor_metric_alert" "http_5xx" {
  name                = "alert-${var.prefix}-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_app_id]
  description         = "Plus de 5 reponses 5xx en 5 minutes : l'API echoue."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# --- 2. Latence -------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "latency" {
  name                = "alert-${var.prefix}-latence"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_app_id]
  description         = "Temps de reponse moyen au-dessus de 2 s : le service ralentit."
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "ResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 2000
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# --- 3. Stabilite : redemarrages -------------------------------------------
resource "azurerm_monitor_metric_alert" "restarts" {
  name                = "alert-${var.prefix}-redemarrages"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_app_id]
  description         = "Plus de 3 redemarrages en 15 minutes : conteneur instable ou sonde en echec."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "RestartCount"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 3
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# --- 4. Budget --------------------------------------------------------------
# Trois seuils sur une seule ressource : 50 %, 80 % et 100 % du plafond.
resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "budget-${var.prefix}"
  resource_group_id = var.resource_group_id

  amount     = var.monthly_budget_eur
  time_grain = "Monthly"

  time_period {
    start_date = "2026-11-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}

# --- Tableau de bord --------------------------------------------------------
# Tuiles de metriques liees au Container App, plus un resume ecrit : un tableau
# de bord doit repondre en un regard, pas seulement afficher des courbes.
resource "azurerm_portal_dashboard" "this" {
  name                = "dash-${var.prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = { x = 0, y = 0, w = 12, h = 2 }
            metadata = {
              type = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = [{
                name = "settings"
                value = {
                  content = "## Kaaru\nRedirections, erreurs, latence et stabilite. Les alertes couvrent les 4 signaux, le budget est plafonne a ${var.monthly_budget_eur} EUR."
                }
              }]
            }
          }
          "1" = {
            position = { x = 0, y = 2, w = 6, h = 4 }
            metadata = {
              type   = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [{ name = "id", value = var.container_app_id }]
            }
          }
          "2" = {
            position = { x = 6, y = 2, w = 6, h = 4 }
            metadata = {
              type   = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [{ name = "id", value = var.log_analytics_id }]
            }
          }
        }
      }
    }
  })
}
