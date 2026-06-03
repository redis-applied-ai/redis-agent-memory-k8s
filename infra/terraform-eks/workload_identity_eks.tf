# Read-only lookup of the UAMI created by the AKS module (../terraform).
# This module never manages the UAMI, the AOAI account, or its role assignment —
# it only adds a second federated credential so the same identity also trusts EKS.
data "azurerm_user_assigned_identity" "ram" {
  name                = var.ram_identity_name
  resource_group_name = var.azure_resource_group
}

# Second federated credential on the SAME UAMI, trusting the EKS OIDC issuer.
# Coexists with the AKS credential (different issuer); names must differ.
#
# The EKS OIDC issuer (https://oidc.eks.<region>.amazonaws.com/id/<hash>) exposes
# a public discovery + JWKS endpoint, which Entra fetches to validate the
# projected ServiceAccount token. The subject and audience are cloud-agnostic and
# match the AKS credential exactly, so RAM's entra config works unchanged.
resource "azurerm_federated_identity_credential" "ram_eks" {
  name                = "${var.ram_identity_name}-ram-sa-eks"
  resource_group_name = var.azure_resource_group
  parent_id           = data.azurerm_user_assigned_identity.ram.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = aws_eks_cluster.ram.identity[0].oidc[0].issuer
  subject             = "system:serviceaccount:${var.ram_namespace}:${var.ram_service_account_name}"
}
