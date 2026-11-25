output "vnet_id" { value = azurerm_virtual_network.this.id }
output "vnet_name" { value = azurerm_virtual_network.this.name }
output "apps_subnet_id" { value = azurerm_subnet.apps.id }
output "apps_subnet_prefix" { value = var.apps_subnet_prefix }
output "data_subnet_id" { value = azurerm_subnet.data.id }
output "apps_nsg_id" { value = azurerm_network_security_group.apps.id }
output "data_nsg_id" { value = azurerm_network_security_group.data.id }
