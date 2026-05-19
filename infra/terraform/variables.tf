variable "cluster_name" {
  description = "Name of the AKS cluster and prefix for related resources"
  type        = string
  default     = "ram-aks"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "ram-aks-rg"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "northeurope"
}

variable "system_node_vm_size" {
  description = "VM size for the AKS system node pool"
  type        = string
  default     = "Standard_D2_v5"
}

variable "system_node_count" {
  description = "Number of nodes in the AKS system node pool"
  type        = number
  default     = 2
}

variable "user_node_vm_size" {
  description = "VM size for the AKS user (redis) node pool"
  type        = string
  default     = "Standard_D4_v5"
}

variable "user_node_count" {
  description = "Number of nodes in the AKS user (redis) node pool"
  type        = number
  default     = 3

  validation {
    condition     = var.user_node_count >= 3
    error_message = "user_node_count must be at least 3."
  }
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the load test VM admin user"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Admin username for the load test VM"
  type        = string
  default     = "azureuser"
}

variable "loadtest_vm_size" {
  description = "VM size for the load test virtual machine"
  type        = string
  default     = "Standard_D4_v5"
}
