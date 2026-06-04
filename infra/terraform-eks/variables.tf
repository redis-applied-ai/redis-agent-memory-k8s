variable "aws_region" {
  description = "AWS region to create the EKS cluster in."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster and prefix for related resources."
  type        = string
  default     = "ram-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane and node group."
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group. Redis Enterprise needs >= 2 vCPU / 4Gi per node."
  type        = string
  default     = "m5.xlarge"
}

variable "node_count" {
  description = "Number of worker nodes. Redis Enterprise cluster wants 3."
  type        = number
  default     = 3
}

variable "availability_zones" {
  description = <<-EOT
    AZs to place the cluster/node subnets in. Must span >= 2 AZs that EKS supports
    for control-plane instances. Defaults are valid for us-east-1 (which excludes
    us-east-1e). Override when changing aws_region.
  EOT
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# --- Azure cross-cloud federation (reads the existing UAMI from the AKS module) ---

variable "azure_resource_group" {
  description = "Resource group that holds the existing RAM UAMI (created by ../terraform / the AKS deployment)."
  type        = string
  default     = "ram-aks-rg"
}

variable "ram_identity_name" {
  description = "Name of the existing User Assigned Managed Identity to federate the EKS ServiceAccount to."
  type        = string
  default     = "ram-aoai-identity"
}

variable "ram_namespace" {
  description = "Kubernetes namespace where the RAM ServiceAccount lives. Must match the helm install namespace."
  type        = string
  default     = "ram"
}

variable "ram_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount the RAM pods run under. Must match the SA the helm chart creates."
  type        = string
  default     = "redis-agent-memory"
}
