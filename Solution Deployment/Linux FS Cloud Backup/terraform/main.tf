#############################################
#### Main Terraform configuration file ######
#############################################

# Variables

variable "tenant_id" {
  type        = string
  description = "The Azure tenant ID"
}

variable "subscription_id" {
  type        = string
  description = "The Azure Subscription ID"
}

# Providers
provider "azuread" {
  tenant_id = var.tenant_id
}

provider "azurerm" {
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  features {}
}


# Service Principal for our backup script
data "azuread_client_config" "current" {}

resource "azuread_application" "appregistration" {
  display_name = "backupapplication"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "backupserviceprinciple" {
  application_id               = azuread_application.appregistration.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Resource Group
resource "azurerm_resource_group" "resourcegroup" {
  name     = "homeresourcegroup"
  location = "West Europe"

  tags = {
    environment = "homesetup"
  }
}

# Network Restricted Storage Account
resource "azurerm_storage_account" "storage" {
  name                = "storageraspberrybackup"
  resource_group_name = azurerm_resource_group.resourcegroup.name

  location                 = azurerm_resource_group.resourcegroup.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Deny"
  }

  tags = {
    environment = "homesetup"
  }
}
