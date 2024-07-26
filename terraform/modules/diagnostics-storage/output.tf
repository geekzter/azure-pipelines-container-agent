output diagnostics_storage_id {
  value       = var.create_files_share ? azurerm_storage_account.diagnostics.0.id : null
}

output diagnostics_storage_key {
  sensitive   = true
  value       = var.create_files_share ? azurerm_storage_account.diagnostics.0.primary_access_key : null
}

output diagnostics_storage_sas {
  sensitive   = true
  value       = var.create_files_share ? data.azurerm_storage_account_sas.diagnostics.0.sas : null
}

output diagnostics_storage_name {
  value       = var.create_files_share ? azurerm_storage_account.diagnostics.0.name : null
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