terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

variable "subscription_id" {
  description = "A prefix used for all resources in this example."
  type        = string
}

variable "prefix" {
  description = "A prefix used for all resources in this example."
  type        = string
}

variable "location" {
  description = "The Azure Region in which all resources will be created."
  type        = string
  default     = "Germany West Central"
}

resource "azurerm_resource_group" "rg" {
  name     = var.prefix
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.prefix
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    "CreatedBy"    = "Terraform"
    "Purpose"      = "Production"
    "Network-Type" = "Spoke"
  }
}

# branch1_subnet_0    = "172.16.0.0/24"
resource "azurerm_subnet" "subnet" {
  name                 = var.prefix
  resource_group_name  = azurerm_virtual_network.vnet.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

