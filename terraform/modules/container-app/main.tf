locals {
  container_registry_name      = element(split("/",var.container_registry_id),length(split("/",var.container_registry_id))-1)
  create_files_share           = var.diagnostics_share_name != null && var.diagnostics_share_name != ""
  diagnostics_volume_name      = "diagnostics"
  environment_variables_template= concat(
    [for key,value in var.environment_variables : {
        name                   = key
        value                  = value
      }
    ],
    [
      {
        name                   = "AZP_POOL"
        secretRef              = "azp-pool-name"
      },
      {
        name                   = "AZP_RUN_ARGS"
        value                  = var.pipeline_agent_run_once ? "--once" : ""
      },
      {
        name                   = "AZP_TOKEN"
        secretRef              = "azp-token"
      },
      {
        name                   = "AZP_URL"
        secretRef              = "azp-url"
      }
    ]
  )
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-5)
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

resource azurerm_container_app_environment agent_container_environment {
  name                         = "${var.resource_group_name}-environment"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  tags                         = var.tags
}

resource azurerm_monitor_diagnostic_setting agent_container_environment {
  name                         = "${azurerm_container_app_environment.agent_container_environment.name}-diagnostics"
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  target_resource_id           = azurerm_container_app_environment.agent_container_environment.id

  enabled_log {
    category_group             = "audit"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category_group             = "allLogs"

    retention_policy {
      enabled                  = false
    }
  }
  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}

resource azurerm_container_app_environment_storage agent_container_environment_share {
  name                         = "diagnostics"
  container_app_environment_id = azurerm_container_app_environment.agent_container_environment.id
  account_name                 = var.diagnostics_storage_share_name
  share_name                   = var.diagnostics_storage_share_name
  access_key                   = var.diagnostics_storage_share_key
  access_mode                  = "ReadWrite"

  count                        = local.create_files_share ? 1 : 0
}

resource azurerm_container_app agent_container_app {
  name                         = "aca-${terraform.workspace}-${var.suffix}-deployment"
  container_app_environment_id = azurerm_container_app_environment.agent_container_environment.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type                       = "UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  registry {
    server                     = "${local.container_registry_name}.azurecr.io"
    identity                   = var.user_assigned_identity_id
  }

  template {
    container {
      name                     = "pipeline-agent"
      image                    = "${local.container_registry_name}.azurecr.io/${var.container_repository}"
      cpu                      = var.pipeline_agent_cpu
      memory                   = "${var.pipeline_agent_memory}Gi"

      dynamic env {
        iterator               = env_var
        for_each               = local.environment_variables_template
        content {
          name                 = env_var.name
          secret_name          = env_var.secretRef
          value                = env_var.value
        }
      }

      volume_mounts {
        name                   = local.diagnostics_volume_name
        path                   = "/mnt/diag"
      }
    }

    min_replicas               = var.pipeline_agent_number_min
    max_replicas               = var.pipeline_agent_number_max

    volume {
      name                     = local.diagnostics_volume_name
      storage_type             = "AzureFile"
      storage_name             = azurerm_container_app_environment_storage.agent_container_environment_share.0.name
    }
  }

  secret {
    name                       = "azp-pool-id"
    value                      = tostring(var.pipeline_agent_pool_id)
  }
  secret {
    name                       = "azp-pool-name"
    value                      = var.pipeline_agent_pool_name
  }
  secret {
    name                       = "azp-url"
    value                      = var.devops_url
  }
  secret {
    name                       = "azp-token"
    value                      = var.devops_pat
  }

  tags                         = var.tags

  lifecycle {
    ignore_changes             = [
      tags
    ]
  }

}

# Container Apps do not have an azurerm provider support for KEDA scaler or Managed Identity (yet), falling back to azapi provider
# resource azapi_resource agent_container_app {
#   name                         = "aca-${terraform.workspace}-${var.suffix}-deployment"
#   location                     = var.location
#   parent_id                    = var.resource_group_id
#   type                         = "Microsoft.App/containerApps@2022-03-01"

#   identity {
#     type                       = "UserAssigned"
#     identity_ids               = [var.user_assigned_identity_id]
#   }

#   tags                         = var.tags

#   body                         = jsonencode({
#     properties: {
#       managedEnvironmentId     = azurerm_container_app_environment.agent_container_environment.id
#       configuration            = {
#         registries             = [
#           {
#             identity           = var.user_assigned_identity_id
#             server             = "${local.container_registry_name}.azurecr.io"
#           }
#         ]
#         secrets                = [
#           {
#             name               = "azp-pool-id"
#             value              = tostring(var.pipeline_agent_pool_id)
#           },
#           {
#             name               = "azp-pool-name"
#             value              = var.pipeline_agent_pool_name
#           },
#           {
#             name               = "azp-url"
#             value              = var.devops_url
#           },
#           {
#             name               = "azp-token"
#             value              = var.devops_pat
#           }
#         ]
#       }
#       template                 = {
#         containers             = [{
#           image                = "${local.container_registry_name}.azurecr.io/${var.container_repository}"
#           name                 = "pipeline-agent"
#           env                  = local.environment_variables_template
#           resources            = {
#             cpu                = var.pipeline_agent_cpu
#             memory             = "${var.pipeline_agent_memory}Gi"
#           }
#           volumeMounts         = local.create_files_share ? [
#             {
#               mountPath        = "/mnt/diag"
#               volumeName       = local.diagnostics_volume_name
#             }
#           ] : []
#         }]
#         scale                  = {
#           minReplicas          = var.pipeline_agent_number_min
#           maxReplicas          = var.pipeline_agent_number_max
#           rules                = [
#             {
#               # https://keda.sh/docs/2.9/scalers/azure-pipelines/
#               name             = "pipeline-agent-scaler"
#               custom           = {
#                 type           = "azure-pipelines"
#                 metadata       = {
#                   poolID       = tostring(var.pipeline_agent_pool_id)
#                   targetPipelinesQueueLength = "1"
#                 },
#                 auth           = [
#                   {
#                     secretRef  = "azp-token"
#                     triggerParameter = "personalAccessToken"
#                   },
#                   {
#                     secretRef  = "azp-url"
#                     triggerParameter: "organizationURL"
#                   }
#                 ]                
#               }
#             }
#           ]
#         }
#         volumes                = local.create_files_share ? [
#           {
#             name               = local.diagnostics_volume_name
#             storageType        = "AzureFile"
#             storageName        = azurerm_container_app_environment_storage.agent_container_environment_share.0.name
#           }
#         ] : []
#       }
#     }
#   })

#   lifecycle {
#     ignore_changes             = [
#       tags
#     ]
#   }
# }