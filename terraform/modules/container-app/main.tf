locals {
  container_registry_name      = element(split("/",var.container_registry_id),length(split("/",var.container_registry_id))-1)
  create_files_share           = var.diagnostics_share_name != null && var.diagnostics_share_name != ""
  devops_url                   = "https://dev.azure.com/${var.devops_org}"
  diagnostics_volume_name      = "diagnostics"
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-5)
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

# Container Apps do not have an azurerm provider resource yet, falling back to azapi provider
resource azapi_resource agent_container_environment {
  name                         = "${var.resource_group_name}-environment"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/managedEnvironments@2022-03-01"
  tags                         = var.tags
  
  body                         = jsonencode({
    properties                 = {
      appLogsConfiguration     = {
        destination            = "log-analytics"
        logAnalyticsConfiguration= {
          customerId           = data.azurerm_log_analytics_workspace.monitor.workspace_id
          sharedKey            = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
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

resource azapi_resource agent_container_environment_share {
  type                         = "Microsoft.App/managedEnvironments/storages@2022-01-01-preview"
  name                         = "diagnostics"
  parent_id                    = azapi_resource.agent_container_environment.id
  body                         = jsonencode({
    properties                 = {
      azureFile                = {
        accessMode             = "ReadWrite"
        accountKey             = var.diagnostics_storage_share_key
        accountName            = var.diagnostics_storage_share_name
        shareName              = var.diagnostics_share_name
      }
    }
  })

  count                        = local.create_files_share ? 1 : 0
}

# Container Apps do not have an azurerm provider resource yet, falling back to azapi provider
resource azapi_resource agent_container_app {
  name                         = "${replace(var.resource_group_name,"-container","")}-app"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/containerApps@2022-03-01"

  identity {
    type                       = "UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  tags                         = var.tags

  body                         = jsonencode({
    properties: {
      managedEnvironmentId     = azapi_resource.agent_container_environment.id
      configuration            = {
        registries             = [
          {
            identity           = var.user_assigned_identity_id
            server             = "${local.container_registry_name}.azurecr.io"
          }
        ]
        secrets                = [
          {
            name               = "azp-pool-id"
            value              = tostring(var.pipeline_agent_pool_id)
          },
          {
            name               = "azp-pool-name"
            value              = var.pipeline_agent_pool_name
          },
          {
            name               = "azp-url"
            value              = local.devops_url
          },
          {
            name               = "azp-token"
            value              = var.devops_pat
          }
        ]
      }
      template                 = {
        containers             = [{
          image                = var.container_image
          name                 = "pipeline-agent"
          env                  = [
            {
              name             = "AZP_POOL"
              secretRef        = "azp-pool-name"
            },
            {
              name             = "AZP_RUN_ARGS"
              value            = var.pipeline_agent_run_once ? "--once" : ""
            },
            {
              name             = "AZP_TOKEN"
              secretRef        = "azp-token"
            },
            {
              name             = "AZP_URL"
              secretRef        = "azp-url"
            },
            {
              name             = "AGENT_DIAGNOSTIC"
              value            = tostring(var.pipeline_agent_diagnostics)
            },
            {
              name             = "VSTSAGENT_TRACE"
              value            = tostring(var.pipeline_agent_diagnostics)
            },
            {
              name             = "VSTS_AGENT_HTTPTRACE"
              value            = tostring(var.pipeline_agent_diagnostics)
            }
          ]
          resources            = {
            cpu                = 0.5
            memory             = "1.0Gi"
          }
          volumeMounts         = local.create_files_share ? [
            {
              mountPath        = "/mnt/diag"
              volumeName       = local.diagnostics_volume_name
            }
          ] : []
        }]
        scale = {
          minReplicas          = 1
          maxReplicas          = 5
          rules                = [
            {
              # https://keda.sh/docs/2.9/scalers/azure-pipelines/
              name             = "pipeline-agent-scaler"
              custom           = {
                type           = "azure-pipelines"
                metadata       = {
                  poolID       = tostring(var.pipeline_agent_pool_id)
                  targetPipelinesQueueLength = "1"
                },
                auth           = [
                  {
                    secretRef  = "azp-token"
                    triggerParameter = "personalAccessToken"
                  },
                  {
                    secretRef  = "azp-url"
                    triggerParameter: "organizationURL"
                  }
                ]                
              }
            }
          ]
        }
        volumes                = local.create_files_share ? [
          {
            name               = local.diagnostics_volume_name
            storageType        = "AzureFile"
            storageName        = azapi_resource.agent_container_environment_share.0.name
          }
        ] : []
      }
    }
  })

  lifecycle {
    ignore_changes             = [
      tags
    ]
  }
}