# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  numeric                      = false
  special                      = false
}

locals {
  aca_agent_pool_id            = var.create_agent_pools ? module.azdo_agent_pools[local.aca_agent_pool_name].pool_id : module.azdo_agent_pool_data[local.aca_agent_pool_name].pool_id
  aca_agent_pool_name          = var.create_agent_pools && (var.aca_agent_pool_name == "Default" || var.aca_agent_pool_name == "" || var.aca_agent_pool_name == null) ? "aca-${var.resource_project}-${terraform.workspace}" : var.aca_agent_pool_name
  aca_agent_pool_url           = "${local.devops_url}/_settings/agentpools?poolId=${local.aca_agent_pool_id}&view=agents"
  admin_object_ids             = concat(var.admin_object_ids,[data.azurerm_client_config.default.object_id])
  agent_identity_client_id     = local.agent_identity_is_precreated ? data.azurerm_user_assigned_identity.pre_created_agent_identity.0.client_id : azurerm_user_assigned_identity.agent_identity.0.client_id
  agent_identity_name          = local.agent_identity_is_precreated ? data.azurerm_user_assigned_identity.pre_created_agent_identity.0.name : azurerm_user_assigned_identity.agent_identity.0.name
  agent_identity_principal_id  = local.agent_identity_is_precreated ? data.azurerm_user_assigned_identity.pre_created_agent_identity.0.principal_id : azurerm_user_assigned_identity.agent_identity.0.principal_id
  agent_identity_resource_id   = local.agent_identity_is_precreated ? var.agent_identity_resource_id : azurerm_user_assigned_identity.agent_identity.0.id
  agent_identity_is_precreated = var.agent_identity_resource_id != "" && var.agent_identity_resource_id != null
  aks_agent_pool_id            = var.create_agent_pools ? module.azdo_agent_pools[local.aks_agent_pool_name].pool_id : module.azdo_agent_pool_data[local.aks_agent_pool_name].pool_id
  aks_agent_pool_name          = var.create_agent_pools && (var.aks_agent_pool_name == "Default" || var.aks_agent_pool_name == "" || var.aks_agent_pool_name == null) ? "aks-${var.resource_project}-${terraform.workspace}" : var.aks_agent_pool_name
  aks_agent_pool_url           = "${local.devops_url}/_settings/agentpools?poolId=${local.aks_agent_pool_id}&view=agents"
  azdo_agent_pools             = var.create_agent_pools ? toset(distinct([local.aca_agent_pool_name, local.aks_agent_pool_name])) : toset(distinct([var.aca_agent_pool_name, var.aks_agent_pool_name]))

  environment_variables        = merge(
    {
      AGENT_DIAGNOSTIC                                          = tostring(var.pipeline_agent_diagnostics)
      PIPELINE_DEMO_AGENT_LOCATION                              = azurerm_resource_group.rg.location
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_CLIENT_ID      = local.agent_identity_client_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_NAME           = local.agent_identity_name
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID   = local.agent_identity_principal_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_RESOURCE_ID    = local.agent_identity_resource_id
      PIPELINE_DEMO_APPLICATION_NAME                            = var.application_name
      PIPELINE_DEMO_APPLICATION_OWNER                           = local.owner
      PIPELINE_DEMO_RESOURCE_GROUP_ID                           = azurerm_resource_group.rg.id
      PIPELINE_DEMO_RESOURCE_GROUP_NAME                         = azurerm_resource_group.rg.name
      PIPELINE_DEMO_RESOURCE_PREFIX                             = var.resource_prefix
      SYSTEM_DEBUG                                              = tostring(var.pipeline_agent_diagnostics)
      VSTSAGENT_TRACE                                           = tostring(var.pipeline_agent_diagnostics)
      VSTS_AGENT_HTTPTRACE                                      = tostring(var.pipeline_agent_diagnostics)
    },
    var.environment_variables
  )
  initial_suffix               = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  initial_tags                 = merge(
    {
      application              = var.application_name
      githubRepo               = "https://github.com/geekzter/azure-pipelines-container-agent"
      owner                    = local.owner
      provisioner              = "terraform"
      provisionerClientId      = data.azurerm_client_config.default.client_id
      provisionerObjectId      = data.azurerm_client_config.default.object_id
      repository               = "azure-pipelines-container-agent"
      runId                    = var.run_id
      suffix                   = local.initial_suffix
      workspace                = terraform.workspace
    },
    var.tags
  )
  kube_config_relative_path    = var.kube_config_path != "" ? var.kube_config_path : "../.kube/${local.workspace_moniker}config"
  kube_config_absolute_path    = var.kube_config_path != "" ? var.kube_config_path : "${path.root}/../.kube/${local.workspace_moniker}config"
  log_analytics_workspace_resource_id   = var.log_analytics_workspace_resource_id != "" && var.log_analytics_workspace_resource_id != null ? var.log_analytics_workspace_resource_id : module.diagnostics_storage.log_analytics_workspace_resource_id
  owner                        = var.application_owner != "" ? var.application_owner : data.azurerm_client_config.default.object_id
  suffix                       = azurerm_resource_group.rg.tags["suffix"] # Ignores updates to var.resource_suffix
  tags                         = azurerm_resource_group.rg.tags           # Ignores updates to var.resource_suffix
  workspace_moniker            = terraform.workspace == "default" ? "" : terraform.workspace
}

resource azurerm_resource_group rg {
  name                         = terraform.workspace == "default" ? "${var.resource_prefix}-${var.resource_project}-${local.initial_suffix}" : "${var.resource_prefix}-${terraform.workspace}-${var.resource_project}-${local.initial_suffix}"
  location                     = var.location

  tags                         = local.initial_tags

  lifecycle {
    ignore_changes             = [
      location,
      name,
      tags["suffix"]
    ]
  }  
}

resource azurerm_user_assigned_identity agent_identity {
  name                         = "${azurerm_resource_group.rg.name}-agent-identity"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location

  lifecycle {
    precondition {
      condition                = var.configure_access_control
      error_message            = "If user_assigned_identity_id is not set, configure_access_control must be set to true"
    }
  }

  count                        = var.agent_identity_resource_id != "" && var.agent_identity_resource_id != null ? 0 : 1
  tags                         = local.tags
}

data azurerm_user_assigned_identity pre_created_agent_identity {
  name                         = element(split("/",var.agent_identity_resource_id),length(split("/",var.agent_identity_resource_id))-1)
  resource_group_name          = element(split("/",var.agent_identity_resource_id),length(split("/",var.agent_identity_resource_id))-5)

  count                        = var.agent_identity_resource_id != "" && var.agent_identity_resource_id != null ? 1 : 0
}

resource azurerm_role_assignment agent_registry_access {
  scope                        = module.container_registry.container_registry_id
  role_definition_name         = "AcrPull"
  principal_id                 = azurerm_user_assigned_identity.agent_identity.0.principal_id

  count                        = (var.agent_identity_resource_id == null || var.agent_identity_resource_id == "") && var.configure_access_control ? 1 : 0
}

resource azurerm_portal_dashboard dashboard {
  name                         = "${azurerm_resource_group.rg.name}-dashboard"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  dashboard_properties         = templatefile("dashboard.template.json",merge(
    local.tags,
    {
      aca_agent_pool_url       = local.aca_agent_pool_url
      aks_agent_pool_url       = local.aks_agent_pool_url
      container_registry_id    = module.container_registry.container_registry_id
      location                 = azurerm_resource_group.rg.location
      log_analytics_workspace_resource_id = local.log_analytics_workspace_resource_id
      pipeline_agent_pool_url  = local.aca_agent_pool_url
      resource_group           = azurerm_resource_group.rg.name
      resource_group_id        = azurerm_resource_group.rg.id
      storage_account_name     = var.create_files_share ? module.diagnostics_storage.0.diagnostics_storage_name : null
      subscription_id          = data.azurerm_subscription.default.id
      subscription_guid        = data.azurerm_subscription.default.subscription_id
      suffix                   = local.suffix
      tenant_id                = data.azurerm_subscription.default.tenant_id      
      workspace                = terraform.workspace
  }))

  tags                         = merge(
    local.tags,
    {
      hidden-title             = "Container Agents (${terraform.workspace})"
    }
  )

  count                        = var.create_portal_dashboard ? 1 : 0
}