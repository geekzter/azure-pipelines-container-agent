resource azurerm_storage_account diagnostics {
  name                         = "${substr(lower(replace(replace(var.resource_group_name,terraform.workspace,""),"/a|e|i|o|u|y|-/","")),0,13)}${terraform.workspace}${substr(var.suffix,-6,-1)}dg"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled   = true
  shared_access_key_enabled    = var.create_files_share

  tags                         = var.tags

  count                        = var.create_files_share ? 1 : 0
}
resource azurerm_monitor_diagnostic_setting diagnostics {
  name                         = "${azurerm_storage_account.diagnostics.0.name}-diagnostics"
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.monitor.0.id
  target_resource_id           = azurerm_storage_account.diagnostics.0.id

  enabled_metric {
    category                   = "Transaction"
  }

  count                        = var.create_log_analytics_workspace && var.create_files_share ? 1 : 0
}

resource time_offset sas_expiry {
  offset_years                 = 1
}
resource time_offset sas_start {
  offset_days                  = -1
}
data azurerm_storage_account_sas diagnostics {
  connection_string            = azurerm_storage_account.diagnostics.0.primary_connection_string
  https_only                   = true

  resource_types {
    service                    = false
    container                  = true
    object                     = true
  }

  services {
    blob                       = true
    queue                      = false
    table                      = true
    file                       = false
  }

  start                        = time_offset.sas_start.rfc3339
  expiry                       = time_offset.sas_expiry.rfc3339  

  permissions {
    add                        = true
    create                     = true
    delete                     = false
    filter                     = false
    list                       = true
    process                    = false
    read                       = false
    tag                        = false
    update                     = true
    write                      = true
  }

  count                        = var.create_files_share ? 1 : 0
}

resource azurerm_storage_share diagnostics {
  name                         = "diagnostics"
  storage_account_name         = azurerm_storage_account.diagnostics.0.name
  quota                        = 128

  count                        = var.create_files_share ? 1 : 0
}

resource azurerm_log_analytics_workspace monitor {
  name                         = "${var.resource_group_name}-loganalytics"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku                          = "PerGB2018"
  retention_in_days            = 30

  count                        = var.create_log_analytics_workspace ? 1 : 0
  tags                         = var.tags
}
resource azurerm_monitor_diagnostic_setting monitor {
  name                         = "${azurerm_log_analytics_workspace.monitor.0.name}-diagnostics"
  target_resource_id           = azurerm_log_analytics_workspace.monitor.0.id
  storage_account_id           = azurerm_storage_account.diagnostics.0.id

  enabled_log {
    category                   = "Audit"
  }
  enabled_metric {
    category                   = "AllMetrics"
  }
  count                        = var.create_log_analytics_workspace && var.create_files_share ? 1 : 0
}
