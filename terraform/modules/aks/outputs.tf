output aks_id {
  value       = azurerm_kubernetes_cluster.aks.id
}

output aks_name {
  value       = azurerm_kubernetes_cluster.aks.name
}

output kube_config {
  sensitive   = true
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
}

output kubernetes_version {
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output node_pool_scale_set_id {
  value       = data.azurerm_resources.scale_sets.resources[0].id
}

output node_resource_group_name {
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}