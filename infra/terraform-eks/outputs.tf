# Output names intentionally mirror ../terraform/outputs.tf so eks-up.sh can
# extract the workload-identity IDs with the same `terraform output -raw` calls.

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.ram.name
}

output "aws_region" {
  description = "AWS region the cluster runs in (used by `aws eks update-kubeconfig`)."
  value       = var.aws_region
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (trusted by the Azure federated identity credential)."
  value       = aws_eks_cluster.ram.identity[0].oidc[0].issuer
}

output "ram_identity_client_id" {
  description = "Client ID of the UAMI the RAM ServiceAccount federates to. Annotate the SA with azure.workload.identity/client-id = <this>."
  value       = data.azurerm_user_assigned_identity.ram.client_id
}

output "ram_identity_tenant_id" {
  description = "Tenant ID for the UAMI (passed to the azure-workload-identity webhook on EKS)."
  value       = data.azurerm_user_assigned_identity.ram.tenant_id
}
