output log_analytics_workspace_resource_id {
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.monitor.0.id : null
}