terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }

  # Optional: use Azure Storage to persist state (uncomment and configure the backend)
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sasockshopstate"
  #   container_name       = "tfstate"
  #   key                  = "sock-shop-on-aks.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
