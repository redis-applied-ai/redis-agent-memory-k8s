terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {}
  # Backend values come from infra/terraform/backend.hcl (gitignored).
  # Run scripts/tf-backend-bootstrap.sh once to create the storage account and generate backend.hcl.
}

provider "azurerm" {
  features {}
}
