variable "subscription_id" {
  description = "Subscription ID of LZ-PREMI1208257 - Vashist"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group"
  type        = string
  default     = "INCA_FICO"
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "inca-sd"
}

variable "existing_vnet_name" {
  description = "Name of the existing company VNet"
  type        = string
}

variable "existing_vnet_resource_group" {
  description = "Resource group of the existing VNet"
  type        = string
}

variable "pe_subnet_name" {
  description = "Existing subnet for private endpoints (Subnet 1)"
  type        = string
}

variable "aca_subnet_name" {
  description = "Existing subnet for Container Apps (Subnet 2), delegated to Microsoft.App/environments"
  type        = string
}

variable "openai_location" {
  description = "Region for the Azure OpenAI account (Central India does not support S0)"
  type        = string
  default     = "eastus2"
}

variable "file_dns_zone_resource_group" {
  description = "Resource group of the EXISTING privatelink.file.core.windows.net zone already linked to the VNet. null = create a new zone"
  type        = string
  default     = null
}

variable "internal_load_balancer_enabled" {
  description = "true = Container Apps environment reachable only from inside the VNet"
  type        = bool
  default     = true
}

variable "openai_embedding_model" {
  type    = string
  default = "text-embedding-3-small"
}

variable "openai_embedding_model_version" {
  type    = string
  default = "1"
}

variable "openai_embedding_capacity" {
  description = "Capacity in thousands of tokens per minute"
  type        = number
  default     = 50
}

variable "openai_chat_model" {
  type    = string
  default = "gpt-4o"
}

variable "openai_chat_model_version" {
  type    = string
  default = "2024-11-20"
}

variable "openai_chat_sku" {
  description = "Deployment SKU for the chat model (Standard or GlobalStandard, depends on quota in the region)"
  type        = string
  default     = "Standard"
}

variable "openai_chat_capacity" {
  description = "Capacity in thousands of tokens per minute"
  type        = number
  default     = 50
}

variable "openai_api_version" {
  type    = string
  default = "2024-12-01-preview"
}

variable "qdrant_collection" {
  type    = string
  default = "inca_sd_knowledge"
}

variable "bot_name" {
  type    = string
  default = "INCA SD Bot"
}

variable "allowed_origins" {
  description = "CORS origins for the API (comma separated)"
  type        = string
  default     = "*"
}

variable "system_prompt" {
  description = "Chat system prompt for INCA_SD. If null, the default prompt inside main.py is used (it says SAP MM)."
  type        = string
  default     = null
}

variable "fastapi_image" {
  description = "Full image path. Placeholder until your image is pushed to ACR, e.g. <acr>.azurecr.io/inca-fastapi:v1"
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "fastapi_port" {
  description = "Port your FastAPI container listens on (8000 for your image, 80 for the placeholder)"
  type        = number
  default     = 80
}

variable "qdrant_image" {
  type    = string
  default = "docker.io/qdrant/qdrant:v1.12.4"
}

variable "tags" {
  type = map(string)
  default = {
    project = "INCA_SD"
    managed = "terraform"
  }
}
