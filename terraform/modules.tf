module diagnostics_storage {
  source                       = "./modules/diagnostics-storage"

  location                     = var.location
  create_log_analytics_workspace = (var.log_analytics_workspace_resource_id != "" && var.log_analytics_workspace_resource_id != null) ? false : true
  create_files_share           = var.create_files_share
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
}

module network {
  source                       = "./modules/network"

  address_space                = var.address_space
  bastion_tags                 = var.bastion_tags
  deploy_bastion               = var.deploy_bastion
  diagnostics_storage_id       = module.diagnostics_storage.diagnostics_storage_id
  firewall_sku_tier            = var.firewall_sku_tier
  gateway_type                 = var.gateway_type
  location                     = var.location
  log_analytics_workspace_resource_id   = local.log_analytics_workspace_resource_id
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags

  count                        = var.deploy_network ? 1 : 0
}

module container_registry {
  source                       = "./modules/container-registry"

  agent_identity_principal_id  = local.agent_identity_principal_id
  configure_access_control     = var.configure_access_control
  container_image              = var.container_repository
  container_registry_id        = var.container_registry_id
  github_repo_access_token     = var.github_repo_access_token
  location                     = var.location
  log_analytics_workspace_resource_id   = local.log_analytics_workspace_resource_id
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
}

module container_agents {
  source                       = "./modules/container-agents"

  container_registry_id        = module.container_registry.container_registry_id
  container_repository         = var.container_repository
  devops_url                   = var.devops_url
  devops_pat                   = var.devops_pat
  diagnostics_storage_share_key= module.diagnostics_storage.diagnostics_storage_key
  diagnostics_storage_share_name= module.diagnostics_storage.diagnostics_storage_name
  diagnostics_share_name       = module.diagnostics_storage.diagnostics_share_name
  environment_variables        = local.environment_variables
  # gateway_id                   = var.deploy_network ? module.network.0.gateway_id : null # Requires upcoming Premium SKU
  gateway_id                   = null
  location                     = var.location
  log_analytics_workspace_resource_id= local.log_analytics_workspace_resource_id
  pipeline_agent_cpu           = var.pipeline_agent_cpu
  pipeline_agent_memory        = var.pipeline_agent_memory
  pipeline_agent_number_max    = var.pipeline_agent_number_max
  pipeline_agent_number_min    = var.pipeline_agent_number_min
  pipeline_agent_pool_id       = var.pipeline_agent_pool_id
  pipeline_agent_pool_name     = var.pipeline_agent_pool_name
  pipeline_agent_run_once      = var.pipeline_agent_run_once
  pipeline_agent_version_id    = var.pipeline_agent_version_id
  resource_group_id            = azurerm_resource_group.rg.id
  resource_group_name          = azurerm_resource_group.rg.name
  subnet_id                    = var.deploy_network ? module.network.0.container_apps_environment_subnet_id : null
  suffix                       = local.suffix
  tags                         = local.tags
  user_assigned_identity_id    = local.agent_identity_resource_id

  depends_on                   = [
    module.container_registry,
    module.network
  ]

  count                        = var.deploy_container_apps ? 1 : 0
}