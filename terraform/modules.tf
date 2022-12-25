module diagnostics_storage {
  source                       = "./modules/diagnostics-storage"

  location                     = var.location
  create_log_analytics_workspace = (var.log_analytics_workspace_resource_id != "" && var.log_analytics_workspace_resource_id != null) ? false : true
  deploy_files_share           = var.deploy_files_share
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
}

module container_agents {
  source                       = "./modules/container-app"

  container_image              = var.container_image
  container_registry_id        = var.container_registry_id
  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat
  location                     = var.location
  log_analytics_workspace_resource_id   = local.log_analytics_workspace_resource_id
  pipeline_agent_pool_id       = var.pipeline_agent_pool_id
  pipeline_agent_pool_name     = var.pipeline_agent_pool_name
  pipeline_agent_version_id    = var.pipeline_agent_version_id
  resource_group_id            = azurerm_resource_group.rg.id
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
  user_assigned_identity_id    = local.user_assigned_identity_id
}