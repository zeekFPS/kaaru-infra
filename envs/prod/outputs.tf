output "api_url" {
  description = "URL publique de l'API et de l'editeur."
  value       = "https://${module.compute.api_fqdn}"
}

output "storage_account_name" {
  value = module.storage.account_name
}

output "worker_job_name" {
  description = "Nom du job d'agregation des scans."
  value       = module.compute.worker_job_name
}

output "log_analytics_workspace" {
  value = module.observability.workspace_name
}

output "acr_name" {
  description = "Registre ou pousser l'image (az acr build --registry <acr_name>)."
  value       = module.compute.registry_name
}

output "acr_login_server" {
  value = module.compute.registry_login_server
}

output "key_vault_name" {
  value = module.security.key_vault_name
}

output "vnet_id" {
  value = module.network.vnet_id
}
