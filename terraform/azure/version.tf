terraform {
  required_version = ">= 1.1.7"
  required_providers {
    # Configure the Azure Provider
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.54.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}
