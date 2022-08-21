#############################################
#### Main Terraform configuration file ######
#############################################

# Provider
provider "azuread" {
  tenant_id = "${var.tenant_id}"
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
    default_action             = "Deny"
  }

  tags = {
    environment = "homesetup"
  }
}