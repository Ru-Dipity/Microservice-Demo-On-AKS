output "resource_group_name" {
  description = "Resource Group 名称"
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "AKS 集群名称"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "AKS 集群 FQDN"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config_raw" {
  description = "AKS kubeconfig（用于 CI/CD 获取集群凭据）"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "ingress_controller_enabled" {
  description = "NGINX Ingress Controller 是否已启用"
  value       = var.ingress_controller_enabled
}
