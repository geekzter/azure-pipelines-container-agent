locals {
  container_registry_name      = element(split("/",var.container_registry_id),length(split("/",var.container_registry_id))-1)
  container_registry_rg        = element(split("/",var.container_registry_id),length(split("/",var.container_registry_id))-5)
  diagnostics_storage_name     = var.diagnostics_storage_id != null ? element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-1) : null
  diagnostics_storage_rg       = var.diagnostics_storage_id != null ? element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-5) : null
}

data azurerm_container_registry registry {
  name                         = local.container_registry_name
  resource_group_name          = local.container_registry_rg
}

data azurerm_storage_account diagnostics {
  name                         = local.diagnostics_storage_name
  resource_group_name          = local.diagnostics_storage_rg

  count                        = var.diagnostics_storage_id != null ? 1 : 0
}

resource azurerm_virtual_network pipeline_network {
  name                         = "${var.resource_group_name}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]

  tags                         = local.all_bastion_tags
}
resource azurerm_monitor_diagnostic_setting pipeline_network {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-logs"
  target_resource_id           = azurerm_virtual_network.pipeline_network.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "VMProtectionAlerts"
  }

  metric {
    category                   = "AllMetrics"
  }
}

resource azurerm_network_security_group default {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-default-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
}

