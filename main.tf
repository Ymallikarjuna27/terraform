############################################
# Existing resource group
############################################
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# API keys for the backend (admin = ingestion/delete, chatbot = chat queries)
resource "random_password" "admin_api_key" {
  length  = 48
  special = false
}

resource "random_password" "chatbot_api_key" {
  length  = 48
  special = false
}

locals {
  rg_name  = data.azurerm_resource_group.rg.name
  location = var.location
  prefix   = var.project
  compact  = replace(var.project, "-", "")
  suffix   = random_string.suffix.result
  tags     = var.tags
}

############################################
# Network: EXISTING company VNet and subnets
############################################
data "azurerm_virtual_network" "vnet" {
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group
}

# Subnet 1 - private endpoints
data "azurerm_subnet" "pe" {
  name                 = var.pe_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group
}

# Subnet 2 - Container Apps (must be empty, dedicated and delegated to Microsoft.App/environments)
data "azurerm_subnet" "aca" {
  name                 = var.aca_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group
}

############################################
# Private DNS zones
############################################
locals {
  dns_zones = {
    file      = "privatelink.file.core.windows.net"
    openai    = "privatelink.openai.azure.com"
    cognitive = "privatelink.cognitiveservices.azure.com"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.dns_zones
  name                = each.value
  resource_group_name = local.rg_name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.dns_zones
  name                  = "${each.key}-link"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  tags                  = local.tags
}

############################################
# Log Analytics (Container Apps logs)
############################################
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${local.prefix}-law"
  resource_group_name = local.rg_name
  location            = local.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

############################################
# Azure Container Registry
############################################
resource "azurerm_container_registry" "acr" {
  name                = "${local.compact}acr${local.suffix}"
  resource_group_name = local.rg_name
  location            = local.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.tags
}

############################################
# Managed identity for the Container App
############################################
resource "azurerm_user_assigned_identity" "app" {
  name                = "${local.prefix}-app-identity"
  resource_group_name = local.rg_name
  location            = local.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

############################################
# Azure Files (qdrant-storage) + private endpoint
############################################
resource "azurerm_storage_account" "files" {
  name                            = "${local.compact}files${local.suffix}"
  resource_group_name             = local.rg_name
  location                        = local.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # required for Azure Files mount in Container Apps
  public_network_access_enabled   = false
  tags                            = local.tags
}

resource "azurerm_storage_share" "qdrant" {
  name               = "qdrant-storage"
  storage_account_id = azurerm_storage_account.files.id
  quota              = 50
}

resource "azurerm_private_endpoint" "files" {
  name                = "${local.prefix}-files-pe"
  resource_group_name = local.rg_name
  location            = local.location
  subnet_id           = data.azurerm_subnet.pe.id
  tags                = local.tags

  private_service_connection {
    name                           = "files-psc"
    private_connection_resource_id = azurerm_storage_account.files.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "file-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["file"].id]
  }
}

############################################
# Azure OpenAI (embeddings) + private endpoint
############################################
resource "azurerm_cognitive_account" "openai" {
  name                          = "${local.prefix}-openai-${local.suffix}"
  resource_group_name           = local.rg_name
  location                      = local.location
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = "${local.prefix}-openai-${local.suffix}"
  public_network_access_enabled = false
  tags                          = local.tags
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.openai_embedding_model
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openai_embedding_model
    version = var.openai_embedding_model_version
  }

  sku {
    name     = "Standard"
    capacity = var.openai_embedding_capacity
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.openai_chat_model
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openai_chat_model
    version = var.openai_chat_model_version
  }

  sku {
    name     = var.openai_chat_sku
    capacity = var.openai_chat_capacity
  }

  # deployments on one account must be created one after another
  depends_on = [azurerm_cognitive_deployment.embedding]
}

resource "azurerm_private_endpoint" "openai" {
  name                = "${local.prefix}-openai-pe"
  resource_group_name = local.rg_name
  location            = local.location
  subnet_id           = data.azurerm_subnet.pe.id
  tags                = local.tags

  private_service_connection {
    name                           = "openai-psc"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "openai-dns"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.zones["openai"].id,
      azurerm_private_dns_zone.zones["cognitive"].id,
    ]
  }
}

resource "azurerm_role_assignment" "openai_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

############################################
# Container Apps Environment (VNet integrated)
############################################
resource "azurerm_container_app_environment" "env" {
  name                           = "${local.prefix}-aca-env"
  resource_group_name            = local.rg_name
  location                       = local.location
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id       = data.azurerm_subnet.aca.id
  internal_load_balancer_enabled = var.internal_load_balancer_enabled
  tags                           = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

# Private DNS for the environment's default domain (needed when the environment is internal)
resource "azurerm_private_dns_zone" "aca" {
  count               = var.internal_load_balancer_enabled ? 1 : 0
  name                = azurerm_container_app_environment.env.default_domain
  resource_group_name = local.rg_name
  tags                = local.tags
}

resource "azurerm_private_dns_a_record" "aca_wildcard" {
  count               = var.internal_load_balancer_enabled ? 1 : 0
  name                = "*"
  zone_name           = azurerm_private_dns_zone.aca[0].name
  resource_group_name = local.rg_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.env.static_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca" {
  count                 = var.internal_load_balancer_enabled ? 1 : 0
  name                  = "aca-link"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.aca[0].name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  tags                  = local.tags
}

# Azure Files share attached to the environment (for Qdrant)
resource "azurerm_container_app_environment_storage" "qdrant" {
  name                         = "qdrant-storage"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.files.name
  share_name                   = azurerm_storage_share.qdrant.name
  access_key                   = azurerm_storage_account.files.primary_access_key
  access_mode                  = "ReadWrite"

  depends_on = [azurerm_private_endpoint.files]
}

############################################
# Container App: FastAPI + Qdrant
############################################
resource "azurerm_container_app" "app" {
  name                         = "${local.prefix}-app-private"
  resource_group_name          = local.rg_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  secret {
    name  = "openai-api-key"
    value = azurerm_cognitive_account.openai.primary_access_key
  }

  secret {
    name  = "admin-api-key"
    value = random_password.admin_api_key.result
  }

  secret {
    name  = "chatbot-api-key"
    value = random_password.chatbot_api_key.result
  }

  ingress {
    external_enabled = true # reachable within the VNet when the environment is internal
    target_port      = var.fastapi_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1 # keep a single replica, Qdrant uses one shared volume

    volume {
      name         = "qdrant-storage"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.qdrant.name
    }

    # Main application
    container {
      name   = "fastapi"
      image  = var.fastapi_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "QDRANT_URL"
        value = "http://localhost:6333"
      }
      env {
        name  = "QDRANT_COLLECTION"
        value = var.qdrant_collection
      }
      env {
        name  = "EMBEDDING_DIMENSIONS"
        value = "1536"
      }
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = azurerm_cognitive_account.openai.endpoint
      }
      env {
        name        = "AZURE_OPENAI_API_KEY"
        secret_name = "openai-api-key"
      }
      env {
        name  = "AZURE_OPENAI_API_VERSION"
        value = var.openai_api_version
      }
      env {
        name  = "AZURE_OPENAI_CHAT_DEPLOYMENT"
        value = azurerm_cognitive_deployment.chat.name
      }
      env {
        name  = "AZURE_OPENAI_EMBEDDING_DEPLOYMENT"
        value = azurerm_cognitive_deployment.embedding.name
      }
      env {
        name        = "ADMIN_API_KEY"
        secret_name = "admin-api-key"
      }
      env {
        name        = "CHATBOT_API_KEY"
        secret_name = "chatbot-api-key"
      }
      env {
        name  = "BOT_NAME"
        value = var.bot_name
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = var.allowed_origins
      }

      dynamic "env" {
        for_each = var.system_prompt == null ? [] : [var.system_prompt]
        content {
          name  = "SYSTEM_PROMPT"
          value = env.value
        }
      }
    }

    # Vector database
    container {
      name   = "qdrant"
      image  = var.qdrant_image
      cpu    = 1.0
      memory = "2Gi"

      volume_mounts {
        name = "qdrant-storage"
        path = "/qdrant/storage"
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.openai_user,
    azurerm_private_endpoint.openai,
  ]
}
