resource "azurerm_virtual_network" "loadtest" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "loadtest" {
  name                 = "loadtest-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.loadtest.name
  address_prefixes     = ["10.0.2.0/28"]
}
