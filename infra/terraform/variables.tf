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

variable "openai_account_name" {
  description = "Name of the Azure OpenAI (Cognitive Services) account. Must be globally unique and used as the custom subdomain."
  type        = string
  default     = "ram-aoai"
}

variable "openai_location" {
  description = "Azure region for the OpenAI account. Defaults to the resource group location; override if the chosen models are not available in that region (e.g. eastus, eastus2, swedencentral)."
  type        = string
  default     = ""
}

variable "openai_sku_name" {
  description = "SKU for the OpenAI account. Standard is S0."
  type        = string
  default     = "S0"
}

variable "openai_chat_deployment_name" {
  description = "Deployment name for the chat completion model. RAM references this name (not the underlying model)."
  type        = string
  default     = "gpt-4o-mini"
}

variable "openai_chat_model" {
  description = "Underlying chat completion model name as published by Azure OpenAI."
  type        = string
  default     = "gpt-4o-mini"
}

variable "openai_chat_model_version" {
  description = "Version of the chat completion model. Check `az cognitiveservices account list-models` for available versions in your region."
  type        = string
  default     = "2024-07-18"
}

variable "openai_chat_sku_name" {
  description = "Deployment SKU for the chat model. GlobalStandard is the modern pay-as-you-go tier and is supported in the widest set of regions; Standard is restricted to a shrinking set of legacy regions. Other options: DataZoneStandard, GlobalBatch, GlobalProvisionedManaged."
  type        = string
  default     = "GlobalStandard"
}

variable "openai_chat_sku_capacity" {
  description = "Capacity (TPM in thousands) for the chat deployment."
  type        = number
  default     = 50
}

variable "openai_embedding_deployment_name" {
  description = "Deployment name for the text embedding model."
  type        = string
  default     = "text-embedding-3-small"
}

variable "openai_embedding_model" {
  description = "Underlying embedding model name as published by Azure OpenAI."
  type        = string
  default     = "text-embedding-3-small"
}

variable "openai_embedding_model_version" {
  description = "Version of the embedding model."
  type        = string
  default     = "1"
}

variable "openai_embedding_sku_name" {
  description = "Deployment SKU for the embedding model. GlobalStandard is the modern pay-as-you-go tier and is supported in the widest set of regions. Other option: DataZoneStandard."
  type        = string
  default     = "GlobalStandard"
}

variable "openai_embedding_sku_capacity" {
  description = "Capacity (TPM in thousands) for the embedding deployment."
  type        = number
  default     = 120
}

variable "ram_identity_name" {
  description = "Name of the User Assigned Managed Identity that the RAM pod will federate to via workload identity."
  type        = string
  default     = "ram-aoai-identity"
}

variable "ram_namespace" {
  description = "Kubernetes namespace where the RAM ServiceAccount lives. Must match the namespace used at helm install time."
  type        = string
  default     = "ram"
}

variable "ram_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount the RAM pods run under. Must match the SA created by the RAM helm chart for federation to bind."
  type        = string
  default     = "redis-agent-memory"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry. Must be globally unique, alphanumeric, 5-50 chars."
  type        = string
  default     = "ramaoai"
}

variable "acr_sku" {
  description = "SKU for the ACR. Basic is sufficient for development; Standard adds geo-redundancy."
  type        = string
  default     = "Basic"
}

variable "canary_namespace" {
  description = "Kubernetes namespace for the AOAI workload-identity canary."
  type        = string
  default     = "aoai-canary"
}

variable "canary_service_account_name" {
  description = "Name of the ServiceAccount the canary pod runs under. The RAM UAMI is federated to this SA so the canary tests the same auth path as RAM."
  type        = string
  default     = "aoai-canary"
}
