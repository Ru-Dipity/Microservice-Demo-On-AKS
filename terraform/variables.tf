# =============================================================================
# Terraform variable definitions
# =============================================================================

variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
  default     = "rg-sockshop-aks"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "germanywestcentral"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "sockshop-aks"
}

variable "kubernetes_version" {
  description = "Kubernetes version (leave empty to use the default)"
  type        = string
  default     = "1.35"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_D2s_v7"
}

variable "node_resource_group" {
  description = "AKS node resource group name (leave empty to auto-generate)"
  type        = string
  default     = ""
}

variable "enable_auto_scaling" {
  description = "Whether to enable cluster auto-scaling"
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Minimum node count for auto-scaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count for auto-scaling"
  type        = number
  default     = 5
}

variable "ingress_controller_enabled" {
  description = "Whether to install the NGINX Ingress Controller via Helm"
  type        = bool
  default     = true
}

variable "ingress_nginx_namespace" {
  description = "NGINX Ingress Controller namespace"
  type        = string
  default     = "ingress-nginx"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    environment = "demo"
    project     = "sock-shop"
  }
}
