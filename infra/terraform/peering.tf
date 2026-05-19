data "azurerm_resources" "aks_node_vnets" {
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  type                = "Microsoft.Network/virtualNetworks"
}

resource "azurerm_virtual_network_peering" "loadtest_to_aks" {
  name                      = "loadtest-to-aks"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.loadtest.name
  remote_virtual_network_id = data.azurerm_resources.aks_node_vnets.resources[0].id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "aks_to_loadtest" {
  name                      = "aks-to-loadtest"
  resource_group_name       = azurerm_kubernetes_cluster.aks.node_resource_group
  virtual_network_name      = data.azurerm_resources.aks_node_vnets.resources[0].name
  remote_virtual_network_id = azurerm_virtual_network.loadtest.id
  allow_virtual_network_access = true
}
