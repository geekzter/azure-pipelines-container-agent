output container_app_id {
  value       = azapi_resource.agent_container_app.id
}
output container_app_name {
  value       = azapi_resource.agent_container_app.name
}

output container_environment_id {
  value       = azurerm_container_app_environment.agent_container_environment.id
}