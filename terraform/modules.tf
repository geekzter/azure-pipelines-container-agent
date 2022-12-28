module diagnostics_storage {
  source                       = "./modules/diagnostics-storage"

  location                     = var.location
  create_log_analytics_workspace = (var.log_analytics_workspace_resource_id != "" && var.log_analytics_workspace_resource_id != null) ? false : true
  create_files_share           = var.create_files_share
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
}

# module container_agents {
#   source                       = "./modules/container-app"

#   container_image              = var.container_image
#   container_registry_id        = var.container_registry_id
#   devops_org                   = var.devops_org
#   devops_pat                   = var.devops_pat
#   diagnostics_storage_share_key= module.diagnostics_storage.diagnostics_storage_key
#   diagnostics_storage_share_name= module.diagnostics_storage.diagnostics_storage_name
#   diagnostics_share_name       = module.diagnostics_storage.diagnostics_share_name
#   environment_variables        = local.environment_variables
#   location                     = var.location
#   log_analytics_workspace_resource_id   = local.log_analytics_workspace_resource_id
#   pipeline_agent_cpu           = var.pipeline_agent_cpu
#   pipeline_agent_memory        = var.pipeline_agent_memory
#   pipeline_agent_number_max    = var.pipeline_agent_number_max
#   pipeline_agent_number_min    = var.pipeline_agent_number_min
#   pipeline_agent_pool_id       = var.pipeline_agent_pool_id
#   pipeline_agent_pool_name     = var.pipeline_agent_pool_name
#   pipeline_agent_run_once      = var.pipeline_agent_run_once
#   pipeline_agent_version_id    = var.pipeline_agent_version_id
#   resource_group_id            = azurerm_resource_group.rg.id
#   resource_group_name          = azurerm_resource_group.rg.name
#   suffix                       = local.suffix
#   tags                         = local.tags
#   user_assigned_identity_id    = local.user_assigned_identity_id

#   depends_on                   = [
#     azurerm_role_assignment.agent_registry_access
#   ]
# }