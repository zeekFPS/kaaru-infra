resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# --- Sous-reseau applicatif -------------------------------------------------
# Delegue a Microsoft.App/environments : c'est la condition pour que les
# Container Apps sortent par ce reseau au lieu du reseau manage Azure.
# Le service endpoint Microsoft.Storage evite de router le trafic de stockage
# par l'Internet public.
resource "azurerm_subnet" "apps" {
  name                 = "snet-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.apps_subnet_prefix]

  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# --- Sous-reseau donnees ----------------------------------------------------
# Separe du sous-reseau applicatif pour que le filtrage puisse differer :
# les points de terminaison prives de stockage vivront ici, joignables depuis
# l'application mais jamais depuis Internet.
resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.data_subnet_prefix]

  service_endpoints = ["Microsoft.Storage"]
}

# --- NSG applicatif ---------------------------------------------------------
resource "azurerm_network_security_group" "apps" {
  name                = "nsg-${var.prefix}-apps"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Entrant : uniquement HTTPS depuis Internet. Rien d'autre n'a de raison
# d'atteindre le sous-reseau applicatif.
resource "azurerm_network_security_rule" "apps_in_https" {
  name                        = "allow-https-internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

resource "azurerm_network_security_rule" "apps_in_deny" {
  name                        = "deny-all-inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

# Sortant : trois destinations nommees, puis refus explicite. Un Container App
# n'a besoin que du stockage, du registre d'images et de l'Internet HTTPS.
resource "azurerm_network_security_rule" "apps_out_storage" {
  name                        = "allow-storage-https"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

resource "azurerm_network_security_rule" "apps_out_acr" {
  name                        = "allow-acr-https"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureContainerRegistry"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

resource "azurerm_network_security_rule" "apps_out_dns" {
  name                        = "allow-dns"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureDNS"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

resource "azurerm_network_security_rule" "apps_out_internet" {
  name                        = "allow-internet-https"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

# NTP : la synchronisation d'horloge des noeuds passe par UDP 123. Sans elle,
# les jetons AAD et les signatures de requetes derivent et les appels echouent
# par intermittence, ce qui est tres difficile a diagnostiquer.
resource "azurerm_network_security_rule" "apps_out_ntp" {
  name                        = "allow-ntp"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

resource "azurerm_network_security_rule" "apps_out_deny" {
  name                        = "deny-all-outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.apps.name
}

resource "azurerm_subnet_network_security_group_association" "apps" {
  subnet_id                 = azurerm_subnet.apps.id
  network_security_group_id = azurerm_network_security_group.apps.id
}

# --- NSG donnees ------------------------------------------------------------
resource "azurerm_network_security_group" "data" {
  name                = "nsg-${var.prefix}-data"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Les donnees ne sont joignables que depuis le sous-reseau applicatif.
resource "azurerm_network_security_rule" "data_in_apps" {
  name                        = "allow-from-apps-https"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.apps_subnet_prefix
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_in_deny" {
  name                        = "deny-internet-inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}
