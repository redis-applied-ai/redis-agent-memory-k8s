output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "node_resource_group" {
  description = "Auto-managed resource group for AKS node resources"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "loadtest_vm_name" {
  description = "Name of the load test virtual machine"
  value       = azurerm_linux_virtual_machine.loadtest.name
}

output "loadtest_vm_public_ip" {
  description = "Public IP address of the load test virtual machine"
  value       = azurerm_public_ip.loadtest.ip_address
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint URL. Use this as the base_url in RAM's embedders/promotion config."
  value       = azurerm_cognitive_account.openai.endpoint
}

output "openai_account_name" {
  description = "Name of the Azure OpenAI account."
  value       = azurerm_cognitive_account.openai.name
}

output "openai_chat_deployment_name" {
  description = "Deployment name to reference for chat completions."
  value       = azurerm_cognitive_deployment.chat.name
}

output "openai_embedding_deployment_name" {
  description = "Deployment name to reference for embeddings."
  value       = azurerm_cognitive_deployment.embedding.name
}

output "ram_identity_client_id" {
  description = "Client ID of the UAMI the RAM ServiceAccount federates to. Annotate the SA with azure.workload.identity/client-id = <this>."
  value       = azurerm_user_assigned_identity.ram.client_id
}

output "ram_identity_tenant_id" {
  description = "Tenant ID for the UAMI."
  value       = azurerm_user_assigned_identity.ram.tenant_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster (used by the federated identity credential)."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "acr_name" {
  description = "Short name of the Azure Container Registry."
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Fully-qualified login server for the ACR (e.g. ramaoai.azurecr.io). Use as the image registry prefix when building/pushing."
  value       = azurerm_container_registry.acr.login_server
}

output "canary_namespace" {
  description = "Kubernetes namespace the canary deploys into."
  value       = var.canary_namespace
}

output "canary_service_account_name" {
  description = "Name of the canary ServiceAccount (federated to the RAM UAMI)."
  value       = var.canary_service_account_name
}
