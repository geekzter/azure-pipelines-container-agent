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

output container_app_id {
  value                        = module.container_agents.container_app_id
}
output container_environment_id {
  value                        = module.container_agents.container_environment_id
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

output log_analytics_workspace_resource_id {
  value                        = local.log_analytics_workspace_resource_id
}

output resource_group_name {
  value                        = azurerm_resource_group.rg.name
}
output resource_suffix {
  value                        = local.suffix
}
