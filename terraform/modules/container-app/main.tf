locals {
  container_registry_name      = element(split("/",var.container_registry_id),length(split("/",var.container_registry_id))-1)
  devops_url                   = "https://dev.azure.com/${var.devops_org}"
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-5)
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

# Container Apps do not have an azurerm provider resource yet, falling back to azapi provider
resource azapi_resource managed_environment {
  name                         = "${var.resource_group_name}-environment"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/managedEnvironments@2022-03-01"
  tags                         = var.tags
  
  body                         = jsonencode({
    properties                 = {
    appLogsConfiguration       = {
      destination              = "log-analytics"
      logAnalyticsConfiguration = {
        customerId             = data.azurerm_log_analytics_workspace.monitor.workspace_id
        sharedKey              = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
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

# Container Apps do not have an azurerm provider resource yet, falling back to azapi provider
resource azapi_resource container_app {
  name                         = "${replace(var.resource_group_name,"-container","")}-app"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/containerApps@2022-03-01"

  identity {
    type                       = "UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  tags                         = var.tags

  body = jsonencode({
    properties: {
      managedEnvironmentId     = azapi_resource.managed_environment.id
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
              name             = "AZP_URL"
              secretRef        = "azp-url"
            },
            {
              name             = "AZP_TOKEN"
              secretRef        = "azp-token"
            }
          ]
          resources            = {
            cpu                = 0.5
            memory             = "1.0Gi"
          }
        }]
        scale = {
          minReplicas          = 1
          maxReplicas          = 5
          rules                = [
            {
              name             = "pipeline-agent-scaler"
              custom           = {
                type           = "azure-pipelines"
                metadata       = {
                  poolID       = tostring(var.pipeline_agent_pool_id)
                  targetPipelinesQueueLength: "1"
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
      }
    }
  })

  lifecycle {
    ignore_changes             = [
      tags
    ]
  }
}