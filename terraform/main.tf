# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  numeric                      = false
  special                      = false
}

locals {
  agent_identity_client_id     = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? data.azurerm_user_assigned_identity.pre_created_agent_identity.0.client_id : azurerm_user_assigned_identity.agent_identity.0.client_id
  agent_identity_name          = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? data.azurerm_user_assigned_identity.pre_created_agent_identity.0.name : azurerm_user_assigned_identity.agent_identity.0.name
  agent_identity_principal_id  = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? data.azurerm_user_assigned_identity.pre_created_agent_identity.0.principal_id : azurerm_user_assigned_identity.agent_identity.0.principal_id
  environment_variables        = merge(
    {
      AGENT_DIAGNOSTIC                                          = tostring(var.pipeline_agent_diagnostics)
      PIPELINE_DEMO_AGENT_LOCATION                              = var.location
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_CLIENT_ID      = local.agent_identity_client_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_NAME           = local.agent_identity_name
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID   = local.agent_identity_principal_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_RESOURCE_ID    = local.user_assigned_identity_id
      PIPELINE_DEMO_APPLICATION_NAME                            = var.application_name
      PIPELINE_DEMO_APPLICATION_OWNER                           = local.owner
      PIPELINE_DEMO_RESOURCE_PREFIX                             = var.resource_prefix
      SYSTEM_DEBUG                                              = tostring(var.pipeline_agent_diagnostics)
      VSTSAGENT_TRACE                                           = tostring(var.pipeline_agent_diagnostics)
      VSTS_AGENT_HTTPTRACE                                      = tostring(var.pipeline_agent_diagnostics)
    },
    var.environment_variables
  )
  log_analytics_workspace_resource_id   = var.log_analytics_workspace_resource_id != "" && var.log_analytics_workspace_resource_id != null ? var.log_analytics_workspace_resource_id : module.diagnostics_storage.log_analytics_workspace_resource_id
  owner                        = var.application_owner != "" ? var.application_owner : data.azurerm_client_config.default.object_id
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  user_assigned_identity_id    = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? var.user_assigned_identity_id : azurerm_user_assigned_identity.agent_identity.0.id
  tags                         = merge(
    {
      application              = var.application_name
      github-repo              = "https://github.com/geekzter/azure-pipelines-container-agent"
      owner                    = local.owner
      provisioner              = "terraform"
      provisioner-client-id    = data.azurerm_client_config.default.client_id
      provisioner-object-id    = data.azurerm_client_config.default.object_id
      repository               = "azure-pipelines-container-agent"
      runid                    = var.run_id
      suffix                   = local.suffix
      workspace                = terraform.workspace
    },
    var.tags
  )  
}

resource azurerm_resource_group rg {
  name                         = terraform.workspace == "default" ? "${var.resource_prefix}-container-agents-${local.suffix}" : "${var.resource_prefix}-${terraform.workspace}-container-agents-${local.suffix}"
  location                     = var.location

  tags                         = local.tags
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

  count                        = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? 0 : 1
  tags                         = local.tags
}
data azurerm_user_assigned_identity pre_created_agent_identity {
  name                         = element(split("/",var.user_assigned_identity_id),length(split("/",var.user_assigned_identity_id))-1)
  resource_group_name          = element(split("/",var.user_assigned_identity_id),length(split("/",var.user_assigned_identity_id))-5)

  count                        = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? 1 : 0
}

resource azurerm_role_assignment agent_registry_access {
  scope                        = var.container_registry_id
  role_definition_name         = "AcrPull"
  principal_id                 = azurerm_user_assigned_identity.agent_identity.0.principal_id

  count                        = (var.user_assigned_identity_id == "" || var.user_assigned_identity_id == null) && var.configure_access_control ? 1 : 0
}