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

  # 可选：使用 Azure Storage 保存 state（取消注释并配置 backend）
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
