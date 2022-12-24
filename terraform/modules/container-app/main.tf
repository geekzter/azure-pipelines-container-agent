locals {
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-5)
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

resource azapi_resource managed_environment {
  name                         = "${var.resource_group_name}-environment"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/managedEnvironments@2022-03-01"
  tags                         = var.tags
  
  body                         = jsonencode({
                                   properties = {
                                #    daprAIInstrumentationKey = var.instrumentation_key
                                   appLogsConfiguration = {
                                     destination = "log-analytics"
                                     logAnalyticsConfiguration = {
                                       customerId = data.azurerm_log_analytics_workspace.monitor.workspace_id
                                       sharedKey  = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
                                     }
                                   }
                                 }
  })

  lifecycle {
    ignore_changes             = [
                                  tags
    ]
  }
}