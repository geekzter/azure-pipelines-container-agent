resource azurerm_log_analytics_workspace monitor {
  name                         = "${var.resource_group_name}-loganalytics"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku                          = "PerGB2018"
  retention_in_days            = 30

  count                        = var.create_log_analytics_workspace ? 1 : 0
  tags                         = var.tags
}

resource azurerm_storage_account diagnostics {
  name                         = "${substr(lower(replace(var.resource_group_name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(var.suffix,-6,-1)}diag"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  enable_https_traffic_only    = true

  tags                         = var.tags
}
resource time_offset sas_expiry {
  offset_years                 = 1
}
resource time_offset sas_start {
  offset_days                  = -1
}
data azurerm_storage_account_sas diagnostics {
  connection_string            = azurerm_storage_account.diagnostics.primary_connection_string
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
}

resource azurerm_storage_account share {
  name                         = "${substr(lower(replace(var.resource_group_name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(var.suffix,-6,-1)}shar"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "FileStorage"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = false # Needs to be off for NFS

  tags                         = var.tags

  count                        = var.deploy_files_share ? 1 : 0
}

resource azurerm_storage_share diagnostics_smb_share {
  name                         = "diagnostics"
  storage_account_name         = azurerm_storage_account.share.0.name
  enabled_protocol             = "SMB"
  quota                        = 128

  count                        = var.deploy_files_share ? 1 : 0
}

locals {
  diagnostics_smb_share        = var.deploy_files_share ? replace(azurerm_storage_share.diagnostics_smb_share.0.url,"https:","") : null
  diagnostics_smb_share_mount_point= var.deploy_files_share ? "/mount/${azurerm_storage_account.share.0.name}/${azurerm_storage_share.diagnostics_smb_share.0.name}" : null
}
