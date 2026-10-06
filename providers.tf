terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.30.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state (create this storage account once, before terraform init)
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "incasdtfstate01"
    container_name       = "tfstate"
    key                  = "inca-sd.terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
