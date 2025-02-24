
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.16.0"
    }
  }

}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "example1" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_id" "storage_account" {
  byte_length = 4
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-example"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = "subnet-example"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
  tags                     = { environment = "production" }
}

resource "azurerm_storage_container" "example" {
  name                  = "private-container"
  storage_account_id    = azurerm_storage_account.example.id
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "storage" {
  name                = "storage-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "storage-privatesc"
    private_connection_resource_id = azurerm_storage_account.example.id
    is_manual_connection           = false
    subresource_names              = ["dfs"]
  }
}
resource "azurerm_private_dns_zone" "storage_dns" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_dns_link" {
  name                  = "storage_dns_link"
  private_dns_zone_name = azurerm_private_dns_zone.storage_dns.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = azurerm_virtual_network.example.id
  registration_enabled  = false
}

resource "azurerm_storage_data_lake_gen2_filesystem" "example" {
  name               = "example"
  storage_account_id = azurerm_storage_account.example.id
}
resource "azurerm_synapse_workspace" "example" {
  name                = var.synapse_workspace_name
  resource_group_name = var.resource_group_name
  location            = "centralus"
  identity { type = "SystemAssigned" }
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.example.id
  sql_administrator_login              = var.sql_admin
  sql_administrator_login_password     = var.sql_password
  managed_virtual_network_enabled      = true
  tags                                 = { environment = "production" }
}

resource "azurerm_synapse_sql_pool" "example" {
  name                 = "sqlpool_example"
  synapse_workspace_id = azurerm_synapse_workspace.example.id
  sku_name             = "DW100c"
  storage_account_type = "GRS"
  tags                 = { environment = "production" }
}

resource "azurerm_private_endpoint" "synapse" {
  name                = "synapse_private_endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "synapse_privatesc"
    private_connection_resource_id = azurerm_synapse_workspace.example.id
    is_manual_connection           = false
    subresource_names              = ["sql"]
  }
}


resource "azurerm_private_dns_zone" "synapse_dns" {
  name                = "privatelink.sql.azuresynapse.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "synapse_dns_link" {
  name                  = "synapse_dns_link"
  private_dns_zone_name = azurerm_private_dns_zone.synapse_dns.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = azurerm_virtual_network.example.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "synapse_a_record" {
  name                = azurerm_synapse_workspace.example.name
  zone_name           = azurerm_private_dns_zone.synapse_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  records             = [azurerm_private_endpoint.synapse.private_service_connection[0].private_ip_address]
}

resource "azurerm_data_factory" "example" {
  name                = var.data_factory_name
  location            = var.location
  resource_group_name = var.resource_group_name
  identity { type = "SystemAssigned" }
  tags = { environment = "production" }
}
resource "azurerm_data_factory_integration_runtime_azure" "example" {
  name            = "example"
  data_factory_id = azurerm_data_factory.example.id
  location        = var.location
}

resource "azurerm_private_endpoint" "example" {
  name                = "example-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "example-connection"
    private_connection_resource_id = azurerm_data_factory.example.id
    subresource_names              = ["dataFactory"] # Data Factory subresource
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.datafactory.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "example-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.example.id
}

resource "azurerm_private_dns_a_record" "example" {
  name                = azurerm_data_factory.example.name
  zone_name           = azurerm_private_dns_zone.example.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.example.private_service_connection[0].private_ip_address]
}















