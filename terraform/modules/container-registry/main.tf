locals {
  container_registry_id        = var.container_registry_id != null && var.container_registry_id != "" ? var.container_registry_id : azurerm_container_registry.image_registry.0.id
  container_registry_name      = element(split("/",local.container_registry_id),length(split("/",local.container_registry_id))-1)
}

resource azurerm_container_registry image_registry {
  name                         = "${substr(lower(replace(var.resource_group_name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(var.suffix,-6,-1)}agent"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.container_registry_id != null && var.container_registry_id != "" ? 0 : 1
}

resource azurerm_monitor_diagnostic_setting image_registry {
  name                         = "${azurerm_container_registry.image_registry.0.name}-logs"
  target_resource_id           = azurerm_container_registry.image_registry.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "ContainerRegistryRepositoryEvents"
  }
  enabled_log {
    category                   = "ContainerRegistryLoginEvents"
  }

  enabled_metric {
    category                   = "AllMetrics"
  }

  count                        = var.container_registry_id != null && var.container_registry_id != "" ? 0 : 1
} 
