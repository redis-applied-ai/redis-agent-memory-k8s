resource "azurerm_federated_identity_credential" "canary" {
  name                = "${var.ram_identity_name}-canary-sa"
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.ram.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${var.canary_namespace}:${var.canary_service_account_name}"
}
