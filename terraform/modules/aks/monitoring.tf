data azurerm_log_analytics_workspace log_analytics {
  name                         = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1)
  resource_group_name          = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5)
}

resource azurerm_log_analytics_solution log_analytics_solution {
  solution_name                = "ContainerInsights" 
  location                     = var.location
  resource_group_name          = data.azurerm_log_analytics_workspace.log_analytics.resource_group_name
  workspace_resource_id        = var.log_analytics_workspace_id
  workspace_name               = data.azurerm_log_analytics_workspace.log_analytics.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/ContainerInsights"
  }
} 

resource azurerm_monitor_diagnostic_setting aks {
  name                         = "${azurerm_kubernetes_cluster.aks.name}-logs"
  target_resource_id           = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "kube-apiserver"
  }
  enabled_log {
    category                   = "kube-audit"
  }
  enabled_log {
    category                   = "kube-audit-admin"
  }
  enabled_log {
    category                   = "kube-controller-manager"
  }
  enabled_log {
    category                   = "kube-scheduler"
  }
  enabled_log {
    category                   = "cluster-autoscaler"
  }
  enabled_log {
    category                   = "guard"
  }

  enabled_metric {
    category                   = "AllMetrics"
  }
} 

resource azurerm_monitor_diagnostic_setting scale_set {
  name                         = "${split("/",data.azurerm_resources.scale_sets.resources[0].id)[8]}-logs"
  target_resource_id           = data.azurerm_resources.scale_sets.resources[0].id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_metric {
    category                   = "AllMetrics"
  }

  lifecycle {
    ignore_changes             = [
      # New values are not known after plan stage, but won't change
      name,
      target_resource_id 
    ]
  }
} 