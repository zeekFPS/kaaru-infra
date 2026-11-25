output "account_name" { value = azurerm_storage_account.this.name }
output "account_id" { value = azurerm_storage_account.this.id }
output "blob_endpoint" { value = azurerm_storage_account.this.primary_blob_endpoint }
output "queue_name" { value = azapi_resource.queue_scans.name }
output "links_table_id" { value = azapi_resource.table_links.id }
output "stats_table_id" { value = azapi_resource.table_stats.id }
output "queue_id" { value = azapi_resource.queue_scans.id }
