output aca_agent_pool_id {
  value                        = local.aca_agent_pool_id
}
output aca_agent_pool_name {
  value                        = local.aca_agent_pool_name
}
resource azurerm_key_vault_secret aca_agent_pool_name {
  name                         = "${terraform.workspace}-aca-pool-name"
  value                        = local.aca_agent_pool_name
  key_vault_id                 = var.key_vault_id
  count                        = var.key_vault_id != null ? 1 : 0
}
output aca_agent_pool_url {
  value                        = local.aca_agent_pool_url
}

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

output aks_agent_pool_id {
  value                        = local.aks_agent_pool_id
}
output aks_agent_pool_name {
  value                        = local.aks_agent_pool_name
}
resource azurerm_key_vault_secret aks_agent_pool_name {
  name                         = "${terraform.workspace}-aks-pool-name"
  value                        = local.aks_agent_pool_name
  key_vault_id                 = var.key_vault_id
  count                        = var.key_vault_id != null ? 1 : 0
}
output aks_agent_pool_url {
  value                        = local.aks_agent_pool_url
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
output diagnostics_storage_key {
  sensitive                    = true
  value                        = module.diagnostics_storage.diagnostics_storage_key
}
output diagnostics_storage_sas {
  sensitive                    = true
  value                        = module.diagnostics_storage.diagnostics_storage_sas
}
output diagnostics_share_url {
  value                        = module.diagnostics_storage.diagnostics_share_url
}
output diagnostics_share_url_with_sas {
  sensitive                    = true
  value                        = "${module.diagnostics_storage.diagnostics_share_url}${module.diagnostics_storage.diagnostics_storage_sas}"
}

output environment_variables {
  value                        = local.environment_variables
}

resource local_file helm_environment_values_file {
  content                      = jsonencode(
    {
      env                      = {
        values                 = [for key, value in { for k, v in local.environment_variables : k => v if k != "PIPELINE_DEMO_JOB_CAPABILITY_ACA" } : {
            name               = key
            value              = value
          }
        ]
      }
    }
  )
  filename                     = "${path.root}/../data/${terraform.workspace}/helm-env-vars-values.json"
}

output helm_environment_values_file_abs_path {
  value                        = abspath(local_file.helm_environment_values_file.filename)
}

output helm_environment_values_file {
  value                        = local_file.helm_environment_values_file.filename
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

output location {
  value                        = azurerm_resource_group.rg.location
}

output log_analytics_workspace_resource_id {
  value                        = local.log_analytics_workspace_resource_id
}

output portal_dashboard_id {
  value                        = var.create_portal_dashboard ? azurerm_portal_dashboard.dashboard.0.id : null
}

output portal_dashboard_url {
  value                        = var.create_portal_dashboard ? "https://portal.azure.com/#@/dashboard/arm${azurerm_portal_dashboard.dashboard.0.id}" : null
}

output resource_group_id {
  value                        = azurerm_resource_group.rg.id
}
output resource_group_name {
  value                        = azurerm_resource_group.rg.name
}
output resource_suffix {
  value                        = local.suffix
}
output subscription_id {
  value                        = data.azurerm_subscription.default.id
}
output subscription_guid {
  value                        = data.azurerm_subscription.default.subscription_id
}

output workspace {
  value                        = terraform.workspace
}