output "api_id" { value = azurerm_container_app.api.id }
output "api_fqdn" { value = azurerm_container_app.api.latest_revision_fqdn }
output "api_url" { value = "https://${azurerm_container_app.api.latest_revision_fqdn}" }
output "worker_job_name" { value = azurerm_container_app_job.worker.name }
output "registry_login_server" { value = azurerm_container_registry.this.login_server }
output "registry_name" { value = azurerm_container_registry.this.name }
