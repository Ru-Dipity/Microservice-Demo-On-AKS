# =============================================================================
# Terraform 变量定义
# =============================================================================

variable "resource_group_name" {
  description = "Azure Resource Group 名称"
  type        = string
  default     = "rg-sockshop"
}

variable "location" {
  description = "Azure 区域"
  type        = string
  default     = "westeurope"
}

variable "cluster_name" {
  description = "AKS 集群名称"
  type        = string
  default     = "aks-sockshop"
}

variable "kubernetes_version" {
  description = "Kubernetes 版本（留空则使用默认）"
  type        = string
  default     = ""
}

variable "node_count" {
  description = "默认节点池节点数量"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "默认节点池 VM 规格"
  type        = string
  default     = "Standard_B2s"
}

variable "node_resource_group" {
  description = "AKS 节点资源组名称（留空则自动生成）"
  type        = string
  default     = ""
}

variable "enable_auto_scaling" {
  description = "是否启用集群自动扩缩容"
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "自动扩缩容最小节点数"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "自动扩缩容最大节点数"
  type        = number
  default     = 5
}

variable "ingress_controller_enabled" {
  description = "是否通过 Helm 安装 NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "ingress_nginx_namespace" {
  description = "NGINX Ingress Controller 命名空间"
  type        = string
  default     = "ingress-nginx"
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default = {
    environment = "demo"
    project     = "sock-shop"
  }
}
