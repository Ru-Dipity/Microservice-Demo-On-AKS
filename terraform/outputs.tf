output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config_raw" {
  description = "AKS kubeconfig (used by CI/CD to obtain cluster credentials)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "ingress_controller_enabled" {
  description = "Whether the NGINX Ingress Controller is enabled"
  value       = var.ingress_controller_enabled
}
