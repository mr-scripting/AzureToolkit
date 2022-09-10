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

# data
data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Service Principal for our backup script
resource "azuread_application" "appregistration" {
  display_name = "backupapplication"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "backupserviceprinciple" {
  application_id               = azuread_application.appregistration.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Generate a Password for the Service Principal
resource "azuread_application_password" "appregistrationPassword" {
  application_object_id = azuread_application.appregistration.object_id
  end_date_relative     = "8765h48m"
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
  public_network_access_enabled = "false"

  network_rules {
    default_action = "Deny"
  }

  tags = {
    environment = "homesetup"
  }
}

# IAM Role assignment over storage
resource "azurerm_role_assignment" "StorageBlobDataOwner" {
  scope                = resource.azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = resource.azuread_service_principal.backupserviceprinciple.id
}

# Output the service principal password (This is not recommended in production cases. Azure Keyvault should be used instead)
output "appId" {
  value = resource.azuread_application.appregistration.id
}
output "displayName" {
  value = resource.azuread_application.appregistration.display_name
}
output "password" {
  value = nonsensitive(resource.azuread_application_password.appregistrationPassword.value)
}
output "tenant" {
  value = var.tenant_id
}
