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

# Container Apps do not have an azurerm provider resource yet, falling back to azapi provider
resource azapi_resource agent_container_environment {
  name                         = "${var.resource_group_name}-environment"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/managedEnvironments@2023-04-01-preview"
  tags                         = var.tags
  
  # schema_validation_enabled    = false

  body                         = jsonencode({
    properties                 = {
      appLogsConfiguration     = {
        destination            = "log-analytics"
        logAnalyticsConfiguration= {
          customerId           = data.azurerm_log_analytics_workspace.monitor.workspace_id
          sharedKey            = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
        }
      }
      # BUG: https://github.com/microsoft/azure-container-apps/issues/522 (NAT Gateway)
      # BUG: https://github.com/microsoft/azure-container-apps/issues/227 (Azure Firewall)
      vnetConfiguration        = var.subnet_id != null ? {
        infrastructureSubnetId = var.subnet_id
        internal               = true
        # Requires Premium SKU
        # outboundSettings       = var.gateway_id != null ? {
        #   outBoundType         = "UserDefinedRouting"
        #   virtualNetworkApplianceIp= var.gateway_id
        # } : null
      } : null
    }
    # sku                        = {
    #   # https://github.com/microsoft/azure-container-apps/issues/452
    #   # name                     = var.gateway_id != null ? "Premium" : "Consumption"
    #   name                     = "Consumption"
    # }
  })

  timeouts {
    create                     = "1h30m"
  }
  lifecycle {
    ignore_changes             = [
      tags
    ]
  }
}
resource azurerm_monitor_diagnostic_setting agent_container_environment {
  name                         = "${azapi_resource.agent_container_environment.name}-diagnostics"
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  target_resource_id           = azapi_resource.agent_container_environment.id

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

resource azapi_resource agent_container_environment_share {
  type                         = "Microsoft.App/managedEnvironments/storages@2023-04-01-preview"
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
  name                         = "aca-${terraform.workspace}-${var.suffix}-deployment"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/containerApps@2023-04-01-preview"

  identity {
    type                       = "UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  tags                         = var.tags

  body                         = jsonencode({
    properties                 = {
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
            value              = var.devops_url
          },
          {
            name               = "azp-token"
            value              = var.devops_pat
          }
        ]
      }
      template                 = {
        containers             = [{
          image                = "${local.container_registry_name}.azurecr.io/${var.container_repository}"
          name                 = "pipeline-agent-app"
          env                  = local.environment_variables_template
          resources            = {
            cpu                = var.pipeline_agent_cpu
            memory             = "${var.pipeline_agent_memory}Gi"
          }
          volumeMounts         = local.create_files_share ? [
            {
              mountPath        = "/mnt/diag"
              volumeName       = local.diagnostics_volume_name
            }
          ] : []
        }]
        scale                  = {
          minReplicas          = var.container_app ? var.pipeline_agent_number_min : 1
          maxReplicas          = var.container_app ? var.pipeline_agent_number_max : 1
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
                    triggerParameter= "organizationURL"
                  }
                ]                
              }
            }
          ]
        }
        volumes                = local.create_files_share ? [
          {
            mountOptions       = "mfsymlinks,cache=strict,nobrl"
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

  count                        = var.container_app || var.container_job ? 1 : 0
}

resource azapi_resource agent_container_job {
  name                         = "aca-${terraform.workspace}-${var.suffix}-job"
  location                     = var.location
  parent_id                    = var.resource_group_id
  type                         = "Microsoft.App/jobs@2023-04-01-preview"

  identity {
    type                       = "UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  tags                         = var.tags

  body                         = jsonencode({
    properties                 = { 
      configuration            = {
        registries             = [
          {
            identity           = var.user_assigned_identity_id
            server             = "${local.container_registry_name}.azurecr.io"
          }
        ]
        replicaRetryLimit      = 1
        replicaTimeout         = 60*60*6 # 6 hours
        eventTriggerConfig     = {
          replicaCompletionCount = 1
          parallelism          = 1
          scale                = {
            minExecutions      = 0
            maxExecutions      = var.pipeline_agent_number_max
            pollingInterval    = 15
            rules              = [
              {
                name           = "azure-pipelines-job"
                type           = "azure-pipelines"
                metadata       = {
                  organizationURLFromEnv = "AZP_URL"
                  personalAccessTokenfromEnv = "AZP_TOKEN"
                  poolID       = tostring(var.pipeline_agent_pool_id)
                  poolName     = var.pipeline_agent_pool_name
                  targetPipelinesQueueLength = "1"
                },
                auth           = [
                  {
                    secretRef  = "azp-token"
                    triggerParameter = "personalAccessToken"
                  },
                  {
                    secretRef  = "azp-url"
                    triggerParameter= "organizationURL"
                  }
                ]                
              }
            ]
          }
        }
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
            value              = var.devops_url
          },
          {
            name               = "azp-token"
            value              = var.devops_pat
          }
        ]
        triggerType            = "Event"
      }
      environmentId            = azapi_resource.agent_container_environment.id
      template                 = {
        containers             = [
          {
            env                = local.environment_variables_template
            image              = "${local.container_registry_name}.azurecr.io/${var.container_repository}"
            name               = "pipeline-agent"
            resources          = {
              cpu              = var.pipeline_agent_cpu
              memory           = "${var.pipeline_agent_memory}Gi"
            }
            volumeMounts       = local.create_files_share ? [
              {
                mountPath      = "/mnt/diag"
                volumeName     = local.diagnostics_volume_name
              }
            ] : []
          }
        ]
        volumes                = local.create_files_share ? [
          {
            mountOptions       = "mfsymlinks,cache=strict,nobrl"
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

  count                        = var.container_job ? 1 : 0
  depends_on                   = [ 
    azapi_resource.agent_container_app 
  ]
}