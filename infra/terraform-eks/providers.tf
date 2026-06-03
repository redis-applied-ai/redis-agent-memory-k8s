terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # POC: local backend. State lives at infra/terraform-eks/terraform.tfstate
  # (gitignored). This module is intentionally decoupled from the AKS module's
  # azurerm backend so `terraform destroy` here never touches AKS/AOAI/UAMI.
}

provider "aws" {
  region = var.aws_region
}

# Used only to read the existing RAM UAMI and add a federated credential to it.
# The UAMI, AOAI account, and role assignment are owned by ../terraform (AKS).
provider "azurerm" {
  features {}
}
