module container_agents {
  source                       = "./modules/container-app"

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat
  location                     = var.location
  pipeline_agent_pool          = var.pipeline_agent_pool
  pipeline_agent_version_id    = var.pipeline_agent_version_id
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  suffix                       = local.suffix
  tags                         = local.tags
  user_assigned_identity_id    = local.user_assigned_identity_id
}