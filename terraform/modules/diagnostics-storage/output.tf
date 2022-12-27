output diagnostics_storage_id {
  value       = azurerm_storage_account.diagnostics.id
}

output diagnostics_storage_key {
  sensitive   = true
  value       = azurerm_storage_account.diagnostics.primary_access_key
}

output diagnostics_storage_sas {
  sensitive   = true
  value       = data.azurerm_storage_account_sas.diagnostics.sas
}

output diagnostics_storage_name {
  value       = azurerm_storage_account.diagnostics.name
}

output diagnostics_share_name {
  value       = var.create_files_share ? azurerm_storage_share.diagnostics.0.name : null
}

output diagnostics_share_url {
  value       = var.create_files_share ? azurerm_storage_share.diagnostics.0.url : null
}


output log_analytics_workspace_resource_id {
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.monitor.0.id : null
}