resource "azurerm_cognitive_account" "openai" {
  name                  = var.openai_account_name
  location              = coalesce(var.openai_location, azurerm_resource_group.rg.location)
  resource_group_name   = azurerm_resource_group.rg.name
  kind                  = "OpenAI"
  sku_name              = var.openai_sku_name
  custom_subdomain_name = var.openai_account_name

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.openai_chat_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openai_chat_model
    version = var.openai_chat_model_version
  }

  scale {
    type     = var.openai_chat_sku_name
    capacity = var.openai_chat_sku_capacity
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.openai_embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openai_embedding_model
    version = var.openai_embedding_model_version
  }

  scale {
    type     = var.openai_embedding_sku_name
    capacity = var.openai_embedding_sku_capacity
  }
}
