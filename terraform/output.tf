output agent_diagnostics_file_share_url {
  value                        = module.diagnostics_storage.diagnostics_share_url
}

output agent_identity_client_id {
  value                        = local.agent_identity_client_id
}
output agent_identity_name {
  value                        = local.agent_identity_name
}
output agent_identity_principal_id {
  value                        = local.agent_identity_principal_id
}

output aks_id {
  value                        = var.deploy_aks ? module.aks_agents.0.aks_id : null
}

output aks_name {
  value                        = var.deploy_aks ? module.aks_agents.0.aks_name : null
}

output container_app_id {
  value                        = var.deploy_container_app ? module.container_app_agents.0.container_app_id : null
}
output container_app_name {
  value                        = var.deploy_container_app ? module.container_app_agents.0.container_app_name : null
}
output container_environment_id {
  value                        = var.deploy_container_app ? module.container_app_agents.0.container_environment_id : null
}
output container_registry_id {
  value                        = module.container_registry.container_registry_id
}
output container_registry_name {
  value                        = module.container_registry.container_registry_name
}
output diagnostics_storage_account_name {
  value                        = module.diagnostics_storage.diagnostics_storage_name
}
output diagnostics_storage_sas {
  sensitive                    = true
  value                        = module.diagnostics_storage.diagnostics_storage_sas
}

output environment_variables {
  value                        = local.environment_variables
}

output gateway_id {
  value                        = var.deploy_network ? module.network.0.gateway_id : null
}

output kube_config {
  sensitive                    = true
  value                        = var.deploy_aks ? module.aks_agents.0.kube_config : null
}

output kubernetes_version {
  value                        = var.deploy_aks ? module.aks_agents.0.kubernetes_version : null
}

output log_analytics_workspace_resource_id {
  value                        = local.log_analytics_workspace_resource_id
}

output resource_group_name {
  value                        = azurerm_resource_group.rg.name
}
output resource_suffix {
  value                        = local.suffix
}
