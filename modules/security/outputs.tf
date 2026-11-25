output "api_identity_id" { value = azurerm_user_assigned_identity.api.id }
output "api_identity_client_id" { value = azurerm_user_assigned_identity.api.client_id }
output "api_identity_principal_id" { value = azurerm_user_assigned_identity.api.principal_id }
output "worker_identity_id" { value = azurerm_user_assigned_identity.worker.id }
output "worker_identity_client_id" { value = azurerm_user_assigned_identity.worker.client_id }
output "worker_identity_principal_id" { value = azurerm_user_assigned_identity.worker.principal_id }
output "key_vault_id" { value = azurerm_key_vault.this.id }
output "key_vault_name" { value = azurerm_key_vault.this.name }
