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
